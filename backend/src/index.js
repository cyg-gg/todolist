const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const pool = require('./db');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'todolist-secret';

app.use(cors());
app.use(express.json());

const signToken = (user) => jwt.sign({ id: user.id, username: user.username }, JWT_SECRET, { expiresIn: '7d' });

const auth = (req, res, next) => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ message: '未登录' });
  }

  try {
    req.user = jwt.verify(header.slice(7), JWT_SECRET);
    next();
  } catch (error) {
    return res.status(401).json({ message: '登录已过期' });
  }
};

async function initDatabase() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      username VARCHAR(50) NOT NULL UNIQUE,
      password VARCHAR(255) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS todos (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      title VARCHAR(255) NOT NULL,
      completed TINYINT(1) NOT NULL DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      CONSTRAINT fk_todos_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  `);

  const [users] = await pool.query('SELECT id FROM users WHERE username = ?', ['admin']);
  if (users.length === 0) {
    await pool.query(
      'INSERT INTO users (username, password) VALUES (?, ?)',
      ['admin', 'admin123']
    );
  }

  const [adminRows] = await pool.query('SELECT id FROM users WHERE username = ?', ['admin']);
  const adminId = adminRows[0]?.id;

  if (adminId) {
    const [todos] = await pool.query('SELECT id FROM todos WHERE user_id = ? AND title = ?', [adminId, '欢迎使用 TodoList']);
    if (todos.length === 0) {
      await pool.query('INSERT INTO todos (user_id, title, completed) VALUES (?, ?, 0)', [adminId, '欢迎使用 TodoList']);
    }
  }
}

app.get('/health', (_req, res) => {
  res.json({ message: 'ok' });
});

app.post('/api/auth/register', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ message: '用户名和密码不能为空' });
  }

  try {
    const [exists] = await pool.query('SELECT id FROM users WHERE username = ?', [username]);
    if (exists.length > 0) {
      return res.status(409).json({ message: '用户名已存在' });
    }

    await pool.query('INSERT INTO users (username, password) VALUES (?, ?)', [username, password]);
    const [rows] = await pool.query('SELECT id, username FROM users WHERE username = ?', [username]);
    const user = rows[0];
    res.json({ token: signToken(user), user });
  } catch (error) {
    res.status(500).json({ message: '注册失败', error: error.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ message: '用户名和密码不能为空' });
  }

  try {
    const [rows] = await pool.query('SELECT id, username, password FROM users WHERE username = ?', [username]);
    const user = rows[0];
    if (!user || user.password !== password) {
      return res.status(401).json({ message: '用户名或密码错误' });
    }

    res.json({ token: signToken(user), user: { id: user.id, username: user.username } });
  } catch (error) {
    res.status(500).json({ message: '登录失败', error: error.message });
  }
});

app.get('/api/todos', auth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, title, completed, created_at, updated_at FROM todos WHERE user_id = ? ORDER BY id DESC',
      [req.user.id]
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: '获取待办失败', error: error.message });
  }
});

app.post('/api/todos', auth, async (req, res) => {
  const { title } = req.body;
  if (!title?.trim()) {
    return res.status(400).json({ message: '待办标题不能为空' });
  }

  try {
    const [result] = await pool.query('INSERT INTO todos (user_id, title, completed) VALUES (?, ?, 0)', [req.user.id, title.trim()]);
    res.json({ id: result.insertId, title: title.trim(), completed: 0 });
  } catch (error) {
    res.status(500).json({ message: '新增待办失败', error: error.message });
  }
});

app.put('/api/todos/:id', auth, async (req, res) => {
  const { id } = req.params;
  const { title, completed } = req.body;

  try {
    const [result] = await pool.query(
      'UPDATE todos SET title = COALESCE(?, title), completed = COALESCE(?, completed) WHERE id = ? AND user_id = ?',
      [title?.trim() || null, typeof completed === 'boolean' ? Number(completed) : null, id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: '待办不存在' });
    }

    res.json({ message: '更新成功' });
  } catch (error) {
    res.status(500).json({ message: '更新待办失败', error: error.message });
  }
});

app.delete('/api/todos/:id', auth, async (req, res) => {
  try {
    const [result] = await pool.query('DELETE FROM todos WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: '待办不存在' });
    }

    res.json({ message: '删除成功' });
  } catch (error) {
    res.status(500).json({ message: '删除待办失败', error: error.message });
  }
});

(async () => {
  try {
    await initDatabase();
    app.listen(3000, '0.0.0.0', () => {
      console.log('Server is running on http://0.0.0.0:3000');
    });
  } catch (error) {
    console.error('数据库初始化失败：', error.message);
    process.exit(1);
  }
})();
