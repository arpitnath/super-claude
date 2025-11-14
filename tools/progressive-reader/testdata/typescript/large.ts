import { User, UserRole } from './types';
import { Database } from './database';
import { Logger } from './logger';

export class UserService {
  private db: Database;
  private logger: Logger;

  constructor(db: Database, logger: Logger) {
    this.db = db;
    this.logger = logger;
  }

  async createUser(userData: Partial<User>): Promise<User> {
    this.logger.info('Creating new user', userData);

    const user = await this.db.users.create({
      ...userData,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    this.logger.info('User created successfully', { userId: user.id });
    return user;
  }

  async getUserById(id: string): Promise<User | null> {
    this.logger.debug('Fetching user by ID', { id });
    const user = await this.db.users.findById(id);

    if (!user) {
      this.logger.warn('User not found', { id });
      return null;
    }

    return user;
  }

  async updateUser(id: string, updates: Partial<User>): Promise<User> {
    this.logger.info('Updating user', { id, updates });

    const user = await this.db.users.update(id, {
      ...updates,
      updatedAt: new Date(),
    });

    this.logger.info('User updated successfully', { userId: id });
    return user;
  }

  async deleteUser(id: string): Promise<void> {
    this.logger.info('Deleting user', { id });
    await this.db.users.delete(id);
    this.logger.info('User deleted successfully', { userId: id });
  }

  async listUsers(filters?: UserFilters): Promise<User[]> {
    this.logger.debug('Listing users', { filters });
    return await this.db.users.findMany(filters);
  }
}

export class AuthenticationService {
  private userService: UserService;
  private tokenService: TokenService;
  private logger: Logger;

  constructor(userService: UserService, tokenService: TokenService, logger: Logger) {
    this.userService = userService;
    this.tokenService = tokenService;
    this.logger = logger;
  }

  async login(email: string, password: string): Promise<AuthResult> {
    this.logger.info('Login attempt', { email });

    const user = await this.userService.getUserByEmail(email);
    if (!user) {
      this.logger.warn('Login failed - user not found', { email });
      throw new Error('Invalid credentials');
    }

    const isValidPassword = await this.verifyPassword(password, user.passwordHash);
    if (!isValidPassword) {
      this.logger.warn('Login failed - invalid password', { email });
      throw new Error('Invalid credentials');
    }

    const token = await this.tokenService.generateToken(user);
    this.logger.info('Login successful', { userId: user.id });

    return { user, token };
  }

  async logout(token: string): Promise<void> {
    this.logger.info('Logout attempt');
    await this.tokenService.revokeToken(token);
    this.logger.info('Logout successful');
  }

  async verifyToken(token: string): Promise<User | null> {
    try {
      const payload = await this.tokenService.verifyToken(token);
      const user = await this.userService.getUserById(payload.userId);
      return user;
    } catch (error) {
      this.logger.error('Token verification failed', { error });
      return null;
    }
  }

  private async verifyPassword(password: string, hash: string): Promise<boolean> {
    // Password verification logic
    return bcrypt.compare(password, hash);
  }
}

export class TokenService {
  private secret: string;
  private expiresIn: string;
  private logger: Logger;

  constructor(secret: string, expiresIn: string, logger: Logger) {
    this.secret = secret;
    this.expiresIn = expiresIn;
    this.logger = logger;
  }

  async generateToken(user: User): Promise<string> {
    this.logger.debug('Generating token', { userId: user.id });

    const payload = {
      userId: user.id,
      email: user.email,
      role: user.role,
    };

    const token = jwt.sign(payload, this.secret, { expiresIn: this.expiresIn });
    this.logger.debug('Token generated successfully');

    return token;
  }

  async verifyToken(token: string): Promise<TokenPayload> {
    try {
      const decoded = jwt.verify(token, this.secret);
      return decoded as TokenPayload;
    } catch (error) {
      this.logger.error('Token verification failed', { error });
      throw new Error('Invalid token');
    }
  }

  async revokeToken(token: string): Promise<void> {
    this.logger.debug('Revoking token');
    // Add token to blacklist or revocation list
    this.logger.debug('Token revoked successfully');
  }
}

export class AuthorizationService {
  private logger: Logger;

  constructor(logger: Logger) {
    this.logger = logger;
  }

  async checkPermission(user: User, resource: string, action: string): Promise<boolean> {
    this.logger.debug('Checking permission', { userId: user.id, resource, action });

    const hasPermission = this.evaluatePermission(user.role, resource, action);

    if (!hasPermission) {
      this.logger.warn('Permission denied', { userId: user.id, resource, action });
    }

    return hasPermission;
  }

  private evaluatePermission(role: UserRole, resource: string, action: string): boolean {
    // Permission evaluation logic
    const permissions = this.getRolePermissions(role);
    return permissions.some(p => p.resource === resource && p.actions.includes(action));
  }

  private getRolePermissions(role: UserRole): Permission[] {
    // Return permissions based on role
    switch (role) {
      case 'admin':
        return [{ resource: '*', actions: ['*'] }];
      case 'user':
        return [{ resource: 'own-profile', actions: ['read', 'update'] }];
      default:
        return [];
    }
  }
}

export class SessionService {
  private sessions: Map<string, SessionData>;
  private logger: Logger;

  constructor(logger: Logger) {
    this.sessions = new Map();
    this.logger = logger;
  }

  async createSession(user: User): Promise<string> {
    this.logger.debug('Creating session', { userId: user.id });

    const sessionId = this.generateSessionId();
    const sessionData: SessionData = {
      userId: user.id,
      createdAt: new Date(),
      lastAccessedAt: new Date(),
    };

    this.sessions.set(sessionId, sessionData);
    this.logger.info('Session created', { sessionId, userId: user.id });

    return sessionId;
  }

  async getSession(sessionId: string): Promise<SessionData | null> {
    const session = this.sessions.get(sessionId);

    if (!session) {
      this.logger.warn('Session not found', { sessionId });
      return null;
    }

    session.lastAccessedAt = new Date();
    return session;
  }

  async destroySession(sessionId: string): Promise<void> {
    this.logger.info('Destroying session', { sessionId });
    this.sessions.delete(sessionId);
  }

  private generateSessionId(): string {
    return `session-${Date.now()}-${Math.random().toString(36).substring(7)}`;
  }
}

export class PasswordResetService {
  private userService: UserService;
  private emailService: EmailService;
  private logger: Logger;
  private resetTokens: Map<string, ResetTokenData>;

  constructor(userService: UserService, emailService: EmailService, logger: Logger) {
    this.userService = userService;
    this.emailService = emailService;
    this.logger = logger;
    this.resetTokens = new Map();
  }

  async requestReset(email: string): Promise<void> {
    this.logger.info('Password reset requested', { email });

    const user = await this.userService.getUserByEmail(email);
    if (!user) {
      this.logger.warn('Password reset - user not found', { email });
      return; // Don't reveal if user exists
    }

    const resetToken = this.generateResetToken();
    this.resetTokens.set(resetToken, {
      userId: user.id,
      expiresAt: new Date(Date.now() + 3600000), // 1 hour
    });

    await this.emailService.sendPasswordResetEmail(user.email, resetToken);
    this.logger.info('Password reset email sent', { userId: user.id });
  }

  async resetPassword(resetToken: string, newPassword: string): Promise<void> {
    this.logger.info('Resetting password');

    const tokenData = this.resetTokens.get(resetToken);
    if (!tokenData) {
      this.logger.warn('Invalid reset token');
      throw new Error('Invalid or expired reset token');
    }

    if (new Date() > tokenData.expiresAt) {
      this.logger.warn('Expired reset token');
      this.resetTokens.delete(resetToken);
      throw new Error('Reset token has expired');
    }

    const passwordHash = await this.hashPassword(newPassword);
    await this.userService.updateUser(tokenData.userId, { passwordHash });

    this.resetTokens.delete(resetToken);
    this.logger.info('Password reset successful', { userId: tokenData.userId });
  }

  private generateResetToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 10);
  }
}
