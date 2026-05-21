import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import tasksRoutes from './routes/tasks.js';

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/tasks', tasksRoutes);

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});