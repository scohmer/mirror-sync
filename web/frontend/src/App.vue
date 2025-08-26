<template>
  <div id="app">
    <header class="header">
      <div class="container">
        <h1>Mirror Sync Dashboard</h1>
      </div>
    </header>

    <div class="container">
      <!-- Connection Status -->
      <div 
        class="connection-status"
        :class="{ 'connected': isConnected, 'disconnected': !isConnected }"
      >
        {{ isConnected ? 'Connected' : 'Disconnected' }}
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="loading">
        <div class="spinner"></div>
      </div>

      <!-- Dashboard Content -->
      <div v-else>
        <!-- Mirror Status Cards -->
        <div class="dashboard-grid">
          <MirrorCard 
            title="Debian Mirror"
            :status="mirrorStatus.debian"
            :lastUpdate="lastUpdate"
          />
          <MirrorCard 
            title="Ubuntu Mirror"
            :status="mirrorStatus.ubuntu"
            :lastUpdate="lastUpdate"
          />
          <MirrorCard 
            title="Rocky Mirror"
            :status="mirrorStatus.rocky"
            :lastUpdate="lastUpdate"
          />
        </div>

        <!-- Container Status -->
        <div class="card">
          <h2 class="card-title">Container Status</h2>
          <ContainerStatus :containers="containers" />
        </div>

        <!-- Recent Logs -->
        <div class="card" style="margin-top: 20px;">
          <h2 class="card-title">Recent Logs</h2>
          <LogViewer :logs="logs" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import MirrorCard from './components/MirrorCard.vue'
import ContainerStatus from './components/ContainerStatus.vue'
import LogViewer from './components/LogViewer.vue'
import ApiService from './services/api.js'
import SocketService from './services/socket.js'

export default {
  name: 'App',
  components: {
    MirrorCard,
    ContainerStatus,
    LogViewer
  },
  data() {
    return {
      loading: true,
      isConnected: false,
      lastUpdate: null,
      mirrorStatus: {
        debian: 'UNKNOWN',
        ubuntu: 'UNKNOWN',
        rocky: 'UNKNOWN'
      },
      containers: [],
      logs: []
    }
  },
  async mounted() {
    await this.initializeApp()
    this.setupWebSocket()
    this.startPeriodicUpdates()
  },
  beforeUnmount() {
    SocketService.disconnect()
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  },
  methods: {
    async initializeApp() {
      try {
        await Promise.all([
          this.fetchStatus(),
          this.fetchContainers(),
          this.fetchLogs()
        ])
        this.loading = false
      } catch (error) {
        console.error('Failed to initialize app:', error)
        this.loading = false
      }
    },
    
    async fetchStatus() {
      try {
        const response = await ApiService.getStatus()
        this.parseStatusResponse(response.data.data)
        this.lastUpdate = new Date(response.data.timestamp)
      } catch (error) {
        console.error('Failed to fetch status:', error)
      }
    },
    
    async fetchContainers() {
      try {
        const response = await ApiService.getContainers()
        this.containers = response.data.data
      } catch (error) {
        console.error('Failed to fetch containers:', error)
      }
    },
    
    async fetchLogs() {
      try {
        const response = await ApiService.getLogs()
        this.logs = response.data.data
      } catch (error) {
        console.error('Failed to fetch logs:', error)
      }
    },
    
    parseStatusResponse(statusOutput) {
      // Parse the monitor script output to extract mirror statuses
      const lines = statusOutput.split('\n')
      
      lines.forEach(line => {
        if (line.includes('Debian') && line.includes('Mirror')) {
          if (line.includes('OK')) this.mirrorStatus.debian = 'OK'
          else if (line.includes('WARNING')) this.mirrorStatus.debian = 'WARNING'
          else if (line.includes('CRITICAL')) this.mirrorStatus.debian = 'CRITICAL'
        }
        if (line.includes('Ubuntu') && line.includes('Mirror')) {
          if (line.includes('OK')) this.mirrorStatus.ubuntu = 'OK'
          else if (line.includes('WARNING')) this.mirrorStatus.ubuntu = 'WARNING'
          else if (line.includes('CRITICAL')) this.mirrorStatus.ubuntu = 'CRITICAL'
        }
        if (line.includes('Rocky') && line.includes('Mirror')) {
          if (line.includes('OK')) this.mirrorStatus.rocky = 'OK'
          else if (line.includes('WARNING')) this.mirrorStatus.rocky = 'WARNING'
          else if (line.includes('CRITICAL')) this.mirrorStatus.rocky = 'CRITICAL'
        }
      })
    },
    
    setupWebSocket() {
      SocketService.connect()
      
      SocketService.on('socket-connected', () => {
        this.isConnected = true
        SocketService.emit('startMonitoring')
      })
      
      SocketService.on('socket-disconnected', () => {
        this.isConnected = false
      })
      
      SocketService.on('statusUpdate', (data) => {
        if (data.status === 'success') {
          this.parseStatusResponse(data.data)
          this.lastUpdate = new Date(data.timestamp)
        }
      })
    },
    
    startPeriodicUpdates() {
      // Update containers and logs every 60 seconds
      this.updateInterval = setInterval(async () => {
        await this.fetchContainers()
        await this.fetchLogs()
      }, 60000)
    }
  }
}
</script>