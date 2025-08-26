<template>
  <div class="log-viewer">
    <div class="log-controls">
      <select v-model="selectedLogLevel" @change="filterLogs">
        <option value="all">All Levels</option>
        <option value="ERROR">Errors Only</option>
        <option value="WARN">Warnings & Errors</option>
        <option value="INFO">Info & Above</option>
        <option value="DEBUG">Debug & Above</option>
      </select>
      
      <button @click="refreshLogs" class="refresh-btn">
        Refresh
      </button>
    </div>
    
    <div class="logs-container" ref="logsContainer">
      <div v-if="filteredLogs.length === 0" class="no-logs">
        No logs available
      </div>
      
      <div 
        v-for="(log, index) in filteredLogs" 
        :key="index"
        class="log-entry"
        :class="`log-${log.level.toLowerCase()}`"
      >
        <span class="log-timestamp" v-if="log.timestamp">
          {{ formatTimestamp(log.timestamp) }}
        </span>
        <span class="log-level">[{{ log.level }}]</span>
        <span class="log-message">{{ log.message }}</span>
      </div>
    </div>
  </div>
</template>

<script>
import ApiService from '../services/api.js'

export default {
  name: 'LogViewer',
  props: {
    logs: {
      type: Array,
      default: () => []
    }
  },
  data() {
    return {
      selectedLogLevel: 'all',
      filteredLogs: []
    }
  },
  watch: {
    logs: {
      handler() {
        this.filterLogs()
      },
      immediate: true
    }
  },
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  methods: {
    filterLogs() {
      if (this.selectedLogLevel === 'all') {
        this.filteredLogs = [...this.logs]
      } else {
        const levelPriority = {
          'DEBUG': 0,
          'INFO': 1,
          'WARN': 2,
          'ERROR': 3
        }
        
        const selectedPriority = levelPriority[this.selectedLogLevel] || 0
        
        this.filteredLogs = this.logs.filter(log => {
          const logPriority = levelPriority[log.level] || 0
          return logPriority >= selectedPriority
        })
      }
    },
    
    async refreshLogs() {
      try {
        const response = await ApiService.getLogs()
        this.$emit('logs-updated', response.data.data)
      } catch (error) {
        console.error('Failed to refresh logs:', error)
      }
    },
    
    formatTimestamp(timestamp) {
      try {
        const date = new Date(timestamp)
        return date.toLocaleTimeString('en-US', { 
          hour12: false,
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit'
        })
      } catch (error) {
        return timestamp
      }
    },
    
    scrollToBottom() {
      this.$nextTick(() => {
        const container = this.$refs.logsContainer
        if (container) {
          container.scrollTop = container.scrollHeight
        }
      })
    }
  }
}
</script>

<style scoped>
.log-viewer {
  display: flex;
  flex-direction: column;
  height: 400px;
}

.log-controls {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
  padding: 10px;
  background: #f8f9fa;
  border-radius: 5px;
}

.log-controls select {
  padding: 5px 10px;
  border: 1px solid #ced4da;
  border-radius: 4px;
  background: white;
}

.refresh-btn {
  padding: 5px 15px;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.refresh-btn:hover {
  background: #5a67d8;
}

.logs-container {
  flex: 1;
  background: #2d3748;
  color: #e2e8f0;
  border-radius: 5px;
  padding: 15px;
  font-family: 'Monaco', 'Menlo', 'Consolas', monospace;
  font-size: 0.85rem;
  overflow-y: auto;
  line-height: 1.4;
}

.no-logs {
  text-align: center;
  color: #a0aec0;
  font-style: italic;
  padding: 20px;
}

.log-entry {
  margin-bottom: 8px;
  padding: 5px 8px;
  border-radius: 3px;
  word-wrap: break-word;
}

.log-entry:hover {
  background: rgba(255, 255, 255, 0.05);
}

.log-timestamp {
  color: #a0aec0;
  margin-right: 10px;
}

.log-level {
  font-weight: bold;
  margin-right: 10px;
  min-width: 60px;
  display: inline-block;
}

.log-message {
  color: #e2e8f0;
}

.log-debug .log-level { color: #9ca3af; }
.log-info .log-level { color: #63b3ed; }
.log-warn .log-level { color: #fbd38d; }
.log-error .log-level { color: #fc8181; }

.log-debug { background: rgba(156, 163, 175, 0.1); }
.log-info { background: rgba(99, 179, 237, 0.1); }
.log-warn { background: rgba(251, 211, 141, 0.1); }
.log-error { background: rgba(252, 129, 129, 0.1); }
</style>