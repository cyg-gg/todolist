<template>
  <div class="container">
    <div v-if="!token" class="card auth-box">
      <h1>TodoList</h1>
      <p class="muted">登录后管理你的待办事项</p>

      <input v-model="authForm.username" placeholder="用户名" />
      <input v-model="authForm.password" type="password" placeholder="密码" />

      <div class="row">
        <button class="primary" @click="login">登录</button>
        <button class="secondary" @click="register">注册</button>
      </div>

      <p class="muted">{{ message }}</p>
    </div>

    <div v-else class="card">
      <div class="hero">
        <div>
          <h1>TodoList</h1>
          <p>欢迎，{{ user?.username }}。你可以在这里管理自己的待办。</p>
        </div>
        <button class="secondary" @click="logout">退出登录</button>
      </div>

      <div class="content">
        <div class="panel">
          <h2>新增待办</h2>
          <input v-model="newTitle" placeholder="输入待办内容" @keyup.enter="addTodo" />
          <button class="primary" @click="addTodo">添加待办</button>
          <p class="muted">{{ message }}</p>
        </div>

        <div class="list">
          <h2>我的待办</h2>
          <div v-if="loading" class="muted">加载中...</div>
          <div v-else-if="todos.length === 0" class="muted">暂无待办，先添加一个吧。</div>
          <div
            v-for="todo in todos"
            :key="todo.id"
            class="todo-item"
            :class="{ done: todo.completed }"
          >
            <span>{{ todo.title }}</span>
            <div class="row">
              <button class="secondary" @click="toggleTodo(todo)">
                {{ todo.completed ? '取消完成' : '完成' }}
              </button>
              <button class="secondary" @click="removeTodo(todo.id)">删除</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import axios from 'axios'

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api'
const api = axios.create({ baseURL: apiBaseUrl })
const token = ref(localStorage.getItem('token') || '')
const user = ref(JSON.parse(localStorage.getItem('user') || 'null'))
const todos = ref([])
const loading = ref(false)
const message = ref('')
const newTitle = ref('')
const authForm = reactive({ username: '', password: '' })

api.interceptors.request.use((config) => {
  if (token.value) {
    config.headers.Authorization = `Bearer ${token.value}`
  }
  return config
})

const setSession = (data) => {
  token.value = data.token
  user.value = data.user
  localStorage.setItem('token', data.token)
  localStorage.setItem('user', JSON.stringify(data.user))
}

const clearSession = () => {
  token.value = ''
  user.value = null
  localStorage.removeItem('token')
  localStorage.removeItem('user')
}

const loadTodos = async () => {
  loading.value = true
  try {
    const { data } = await api.get('/todos')
    todos.value = data
  } catch (error) {
    message.value = error.response?.data?.message || '获取待办失败'
  } finally {
    loading.value = false
  }
}

const login = async () => {
  message.value = ''
  try {
    const { data } = await api.post('/auth/login', authForm)
    setSession(data)
    await loadTodos()
  } catch (error) {
    message.value = error.response?.data?.message || '登录失败'
  }
}

const register = async () => {
  message.value = ''
  try {
    const { data } = await api.post('/auth/register', authForm)
    setSession(data)
    await loadTodos()
  } catch (error) {
    message.value = error.response?.data?.message || '注册失败'
  }
}

const logout = () => {
  clearSession()
  todos.value = []
  authForm.username = ''
  authForm.password = ''
}

const addTodo = async () => {
  if (!newTitle.value.trim()) {
    message.value = '请输入待办内容'
    return
  }
  try {
    await api.post('/todos', { title: newTitle.value })
    newTitle.value = ''
    await loadTodos()
  } catch (error) {
    message.value = error.response?.data?.message || '新增失败'
  }
}

const toggleTodo = async (todo) => {
  try {
    await api.put(`/todos/${todo.id}`, { completed: !todo.completed })
    await loadTodos()
  } catch (error) {
    message.value = error.response?.data?.message || '更新失败'
  }
}

const removeTodo = async (id) => {
  try {
    await api.delete(`/todos/${id}`)
    await loadTodos()
  } catch (error) {
    message.value = error.response?.data?.message || '删除失败'
  }
}

onMounted(() => {
  if (token.value) {
    loadTodos()
  }
})
</script>
