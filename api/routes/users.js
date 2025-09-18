const express = require('express');
const Joi = require('joi');
const { runQuery, getQuery, allQuery } = require('../config/database');

const router = express.Router();

// Schema de validação para usuário
const userSchema = Joi.object({
  full_name: Joi.string().min(2).max(100).required(),
  email: Joi.string().email().required(),
  cpf: Joi.string().pattern(/^\d{11}$/).optional(),
  rg: Joi.string().min(5).max(20).optional(),
  phone: Joi.string().pattern(/^\d{10,11}$/).optional(),
  address: Joi.string().max(255).optional()
});

// Schema para atualização (todos os campos opcionais)
const updateUserSchema = Joi.object({
  full_name: Joi.string().min(2).max(100).optional(),
  email: Joi.string().email().optional(),
  cpf: Joi.string().pattern(/^\d{11}$/).optional(),
  rg: Joi.string().min(5).max(20).optional(),
  phone: Joi.string().pattern(/^\d{10,11}$/).optional(),
  address: Joi.string().max(255).optional()
});

// Middleware de validação
const validateUser = (schema) => {
  return (req, res, next) => {
    const { error } = schema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Dados inválidos',
        details: error.details.map(detail => detail.message)
      });
    }
    next();
  };
};

// GET /api/users - Listar usuários com paginação
router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;

    // Contar total de registros
    const countResult = await getQuery('SELECT COUNT(*) as total FROM users');
    const total = countResult.total;

    // Buscar usuários com paginação
    const users = await allQuery(
      'SELECT id, full_name, email, cpf, rg, phone, address, created_at, updated_at FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [limit, offset]
    );

    res.json({
      data: users,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Erro ao buscar usuários:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// GET /api/users/:id - Buscar usuário por ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!/^\d+$/.test(id)) {
      return res.status(400).json({ error: 'ID deve ser um número' });
    }

    const user = await getQuery(
      'SELECT id, full_name, email, cpf, rg, phone, address, created_at, updated_at FROM users WHERE id = ?',
      [id]
    );

    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    res.json({ data: user });
  } catch (error) {
    console.error('Erro ao buscar usuário:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// POST /api/users - Criar novo usuário
router.post('/', validateUser(userSchema), async (req, res) => {
  try {
    const { full_name, email, cpf, rg, phone, address } = req.body;

    // Verificar se email já existe
    const existingUser = await getQuery('SELECT id FROM users WHERE email = ?', [email]);
    if (existingUser) {
      return res.status(409).json({ error: 'Email já cadastrado' });
    }

    // Verificar se CPF já existe (se fornecido)
    if (cpf) {
      const existingCpf = await getQuery('SELECT id FROM users WHERE cpf = ?', [cpf]);
      if (existingCpf) {
        return res.status(409).json({ error: 'CPF já cadastrado' });
      }
    }

    const result = await runQuery(
      `INSERT INTO users (full_name, email, cpf, rg, phone, address) 
       VALUES (?, ?, ?, ?, ?, ?)`,
      [full_name, email, cpf || null, rg || null, phone || null, address || null]
    );

    const newUser = await getQuery(
      'SELECT id, full_name, email, cpf, rg, phone, address, created_at, updated_at FROM users WHERE id = ?',
      [result.id]
    );

    res.status(201).json({
      message: 'Usuário criado com sucesso',
      data: newUser
    });
  } catch (error) {
    console.error('Erro ao criar usuário:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// PUT /api/users/:id - Atualizar usuário
router.put('/:id', validateUser(updateUserSchema), async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!/^\d+$/.test(id)) {
      return res.status(400).json({ error: 'ID deve ser um número' });
    }

    // Verificar se usuário existe
    const existingUser = await getQuery('SELECT id FROM users WHERE id = ?', [id]);
    if (!existingUser) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    const { full_name, email, cpf, rg, phone, address } = req.body;

    // Verificar se email já existe (para outro usuário)
    if (email) {
      const emailExists = await getQuery('SELECT id FROM users WHERE email = ? AND id != ?', [email, id]);
      if (emailExists) {
        return res.status(409).json({ error: 'Email já cadastrado para outro usuário' });
      }
    }

    // Verificar se CPF já existe (para outro usuário)
    if (cpf) {
      const cpfExists = await getQuery('SELECT id FROM users WHERE cpf = ? AND id != ?', [cpf, id]);
      if (cpfExists) {
        return res.status(409).json({ error: 'CPF já cadastrado para outro usuário' });
      }
    }

    // Construir query de atualização dinamicamente
    const updates = [];
    const values = [];

    if (full_name !== undefined) {
      updates.push('full_name = ?');
      values.push(full_name);
    }
    if (email !== undefined) {
      updates.push('email = ?');
      values.push(email);
    }
    if (cpf !== undefined) {
      updates.push('cpf = ?');
      values.push(cpf);
    }
    if (rg !== undefined) {
      updates.push('rg = ?');
      values.push(rg);
    }
    if (phone !== undefined) {
      updates.push('phone = ?');
      values.push(phone);
    }
    if (address !== undefined) {
      updates.push('address = ?');
      values.push(address);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'Nenhum campo para atualizar' });
    }

    updates.push('updated_at = CURRENT_TIMESTAMP');
    values.push(id);

    await runQuery(
      `UPDATE users SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    const updatedUser = await getQuery(
      'SELECT id, full_name, email, cpf, rg, phone, address, created_at, updated_at FROM users WHERE id = ?',
      [id]
    );

    res.json({
      message: 'Usuário atualizado com sucesso',
      data: updatedUser
    });
  } catch (error) {
    console.error('Erro ao atualizar usuário:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// DELETE /api/users/:id - Remover usuário
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!/^\d+$/.test(id)) {
      return res.status(400).json({ error: 'ID deve ser um número' });
    }

    const result = await runQuery('DELETE FROM users WHERE id = ?', [id]);

    if (result.changes === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    res.json({ message: 'Usuário removido com sucesso' });
  } catch (error) {
    console.error('Erro ao remover usuário:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// GET /api/users/search/:term - Buscar usuários por termo
router.get('/search/:term', async (req, res) => {
  try {
    const { term } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;

    const searchTerm = `%${term}%`;

    const users = await allQuery(
      `SELECT id, full_name, email, cpf, rg, phone, address, created_at, updated_at 
       FROM users 
       WHERE full_name LIKE ? OR email LIKE ? OR phone LIKE ?
       ORDER BY created_at DESC 
       LIMIT ? OFFSET ?`,
      [searchTerm, searchTerm, searchTerm, limit, offset]
    );

    res.json({
      data: users,
      search_term: term,
      pagination: {
        page,
        limit
      }
    });
  } catch (error) {
    console.error('Erro ao buscar usuários:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

module.exports = router;