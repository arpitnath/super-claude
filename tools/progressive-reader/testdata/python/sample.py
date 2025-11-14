from typing import List, Optional
from dataclasses import dataclass
import asyncio


@dataclass
class User:
    id: str
    email: str
    name: str


class UserRepository:
    def __init__(self, db_connection):
        self.db = db_connection

    async def find_by_id(self, user_id: str) -> Optional[User]:
        """Find a user by their ID"""
        result = await self.db.query("SELECT * FROM users WHERE id = ?", user_id)
        if result:
            return User(**result)
        return None

    async def create(self, user: User) -> User:
        """Create a new user in the database"""
        await self.db.execute(
            "INSERT INTO users (id, email, name) VALUES (?, ?, ?)",
            user.id, user.email, user.name
        )
        return user

    async def delete(self, user_id: str) -> bool:
        """Delete a user by ID"""
        result = await self.db.execute("DELETE FROM users WHERE id = ?", user_id)
        return result.rows_affected > 0


class AuthenticationService:
    def __init__(self, user_repo: UserRepository, token_service):
        self.user_repo = user_repo
        self.token_service = token_service

    async def authenticate(self, email: str, password: str) -> str:
        """Authenticate user and return access token"""
        user = await self.user_repo.find_by_email(email)

        if not user or not self.verify_password(password, user.password_hash):
            raise ValueError("Invalid credentials")

        token = self.token_service.generate_token(user.id)
        return token

    def verify_password(self, password: str, password_hash: str) -> bool:
        """Verify password against hash"""
        import bcrypt
        return bcrypt.checkpw(password.encode(), password_hash.encode())


class TokenService:
    def __init__(self, secret_key: str, expiry_hours: int = 24):
        self.secret_key = secret_key
        self.expiry_hours = expiry_hours

    def generate_token(self, user_id: str) -> str:
        """Generate JWT token for user"""
        import jwt
        from datetime import datetime, timedelta

        payload = {
            'user_id': user_id,
            'exp': datetime.utcnow() + timedelta(hours=self.expiry_hours)
        }

        return jwt.encode(payload, self.secret_key, algorithm='HS256')

    def verify_token(self, token: str) -> Optional[str]:
        """Verify token and return user ID"""
        import jwt

        try:
            payload = jwt.decode(token, self.secret_key, algorithms=['HS256'])
            return payload.get('user_id')
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None


def main():
    """Main entry point"""
    print("Starting application...")
    asyncio.run(run_server())


async def run_server():
    """Run the application server"""
    from aiohttp import web

    app = web.Application()
    # Setup routes here
    web.run_app(app, host='0.0.0.0', port=8080)


if __name__ == '__main__':
    main()
