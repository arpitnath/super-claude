package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
)

type User struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
}

type UserRepository struct {
	db *Database
}

func NewUserRepository(db *Database) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	var user User
	err := r.db.QueryRow(ctx, "SELECT id, email, name FROM users WHERE id = $1", id).Scan(
		&user.ID, &user.Email, &user.Name,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to find user: %w", err)
	}
	return &user, nil
}

func (r *UserRepository) Create(ctx context.Context, user *User) error {
	_, err := r.db.Exec(ctx,
		"INSERT INTO users (id, email, name) VALUES ($1, $2, $3)",
		user.ID, user.Email, user.Name,
	)
	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}
	return nil
}

func (r *UserRepository) Delete(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx, "DELETE FROM users WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}
	return nil
}

type AuthService struct {
	userRepo     *UserRepository
	tokenService *TokenService
}

func NewAuthService(userRepo *UserRepository, tokenService *TokenService) *AuthService {
	return &AuthService{
		userRepo:     userRepo,
		tokenService: tokenService,
	}
}

func (s *AuthService) Authenticate(ctx context.Context, email, password string) (string, error) {
	user, err := s.userRepo.FindByEmail(ctx, email)
	if err != nil {
		return "", fmt.Errorf("authentication failed: %w", err)
	}

	if !s.verifyPassword(password, user.PasswordHash) {
		return "", fmt.Errorf("invalid credentials")
	}

	token, err := s.tokenService.GenerateToken(user.ID)
	if err != nil {
		return "", fmt.Errorf("failed to generate token: %w", err)
	}

	return token, nil
}

func (s *AuthService) verifyPassword(password, hash string) bool {
	// Password verification logic
	return true
}

type TokenService struct {
	secretKey string
	expiryHours int
}

func NewTokenService(secretKey string, expiryHours int) *TokenService {
	return &TokenService{
		secretKey:   secretKey,
		expiryHours: expiryHours,
	}
}

func (s *TokenService) GenerateToken(userID string) (string, error) {
	// JWT token generation logic
	return fmt.Sprintf("token-%s", userID), nil
}

func (s *TokenService) VerifyToken(token string) (string, error) {
	// Token verification logic
	return "", nil
}

func main() {
	log.Println("Starting server...")

	http.HandleFunc("/health", healthCheckHandler)
	http.HandleFunc("/users", usersHandler)

	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "OK")
}

func usersHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"message": "Users endpoint"}`)
}
