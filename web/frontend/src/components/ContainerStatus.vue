<template>
  <div class="container-status">
    <div v-if="containers.length === 0" class="no-containers">
      No mirror containers are currently running
    </div>
    
    <div v-else class="containers-grid">
      <div 
        v-for="container in containers" 
        :key="container.ID || container.Id"
        class="container-card"
      >
        <div class="container-header">
          <h4 class="container-name">{{ getContainerName(container) }}</h4>
          <span 
            class="container-status-badge"
            :class="getStatusClass(container.State || container.Status)"
          >
            {{ formatStatus(container.State || container.Status) }}
          </span>
        </div>
        
        <div class="container-details">
          <div class="detail-row">
            <span class="label">Image:</span>
            <span class="value">{{ container.Image }}</span>
          </div>
          <div class="detail-row" v-if="container.Created">
            <span class="label">Created:</span>
            <span class="value">{{ formatDate(container.Created) }}</span>
          </div>
          <div class="detail-row" v-if="container.Ports && container.Ports.length">
            <span class="label">Ports:</span>
            <span class="value">{{ formatPorts(container.Ports) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'ContainerStatus',
  props: {
    containers: {
      type: Array,
      default: () => []
    }
  },
  methods: {
    getContainerName(container) {
      if (container.Names && container.Names.length > 0) {
        return container.Names[0].replace(/^\//, '')
      }
      return container.Name || container.ID || container.Id || 'Unknown'
    },
    
    getStatusClass(status) {
      if (!status) return 'status-unknown'
      
      const statusLower = status.toLowerCase()
      if (statusLower.includes('running') || statusLower === 'up') {
        return 'status-running'
      } else if (statusLower.includes('exited') || statusLower.includes('stopped')) {
        return 'status-stopped'
      } else if (statusLower.includes('restarting')) {
        return 'status-restarting'
      }
      return 'status-unknown'
    },
    
    formatStatus(status) {
      if (!status) return 'Unknown'
      return status.charAt(0).toUpperCase() + status.slice(1)
    },
    
    formatDate(dateString) {
      try {
        const date = new Date(dateString * 1000) // Unix timestamp
        return new Intl.DateTimeFormat('en-US', {
          month: 'short',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        }).format(date)
      } catch (error) {
        return 'Unknown'
      }
    },
    
    formatPorts(ports) {
      if (!ports || !Array.isArray(ports)) return 'None'
      
      return ports
        .map(port => {
          if (port.PublicPort && port.PrivatePort) {
            return `${port.PublicPort}:${port.PrivatePort}`
          }
          return port.PrivatePort || port.PublicPort || ''
        })
        .filter(port => port)
        .join(', ')
    }
  }
}
</script>

<style scoped>
.no-containers {
  text-align: center;
  color: #6c757d;
  padding: 20px;
  font-style: italic;
}

.containers-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 15px;
}

.container-card {
  border: 1px solid #e0e6ed;
  border-radius: 8px;
  padding: 15px;
  background: #f8f9fa;
}

.container-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.container-name {
  font-size: 1.1rem;
  font-weight: 600;
  color: #2c3e50;
  margin: 0;
}

.container-status-badge {
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 0.8rem;
  font-weight: 500;
  text-transform: uppercase;
}

.status-running {
  background-color: #d4edda;
  color: #155724;
}

.status-stopped {
  background-color: #f8d7da;
  color: #721c24;
}

.status-restarting {
  background-color: #fff3cd;
  color: #856404;
}

.status-unknown {
  background-color: #e2e3e5;
  color: #383d41;
}

.container-details {
  space-y: 8px;
}

.detail-row {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
}

.label {
  font-weight: 500;
  color: #495057;
}

.value {
  color: #6c757d;
  font-family: monospace;
  font-size: 0.9rem;
  text-align: right;
  max-width: 60%;
  word-break: break-all;
}
</style>