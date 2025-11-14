const express = require('express');
const bodyParser = require('body-parser');

class UserController {
  constructor(userService) {
    this.userService = userService;
  }

  async getUser(req, res) {
    try {
      const user = await this.userService.findById(req.params.id);
      res.json(user);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async createUser(req, res) {
    try {
      const user = await this.userService.create(req.body);
      res.status(201).json(user);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
}

class AuthController {
  constructor(authService) {
    this.authService = authService;
  }

  async login(req, res) {
    const { email, password } = req.body;

    try {
      const token = await this.authService.authenticate(email, password);
      res.json({ token });
    } catch (error) {
      res.status(401).json({ error: 'Invalid credentials' });
    }
  }

  async logout(req, res) {
    await this.authService.revokeToken(req.headers.authorization);
    res.status(204).send();
  }
}

function setupRoutes(app, userController, authController) {
  app.get('/users/:id', (req, res) => userController.getUser(req, res));
  app.post('/users', (req, res) => userController.createUser(req, res));
  app.post('/auth/login', (req, res) => authController.login(req, res));
  app.post('/auth/logout', (req, res) => authController.logout(req, res));
}

module.exports = { UserController, AuthController, setupRoutes };
