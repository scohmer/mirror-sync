import axios from 'axios'

const API_BASE_URL = process.env.NODE_ENV === 'production' 
  ? '/api' 
  : 'http://localhost:3001/api'

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// Request interceptor
api.interceptors.request.use(
  config => {
    console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`)
    return config
  },
  error => {
    console.error('API Request Error:', error)
    return Promise.reject(error)
  }
)

// Response interceptor
api.interceptors.response.use(
  response => {
    console.log(`API Response: ${response.status} ${response.config.url}`)
    return response
  },
  error => {
    console.error('API Response Error:', error.response?.data || error.message)
    return Promise.reject(error)
  }
)

const ApiService = {
  // Get overall mirror status
  async getStatus() {
    return await api.get('/status')
  },

  // Get detailed status report
  async getReport() {
    return await api.get('/report')
  },

  // Get container status
  async getContainers() {
    return await api.get('/containers')
  },

  // Get logs
  async getLogs(type = 'monitor', lines = 100) {
    const params = new URLSearchParams()
    if (lines) params.append('lines', lines.toString())
    
    const url = type ? `/logs/${type}` : '/logs'
    const queryString = params.toString()
    
    return await api.get(`${url}${queryString ? `?${queryString}` : ''}`)
  }
}

export default ApiService