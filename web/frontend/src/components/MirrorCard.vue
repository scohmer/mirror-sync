<template>
  <div class="card mirror-card">
    <h3 class="card-title">{{ title }}</h3>
    
    <div class="status-section">
      <span 
        class="status-indicator"
        :class="`status-${status.toLowerCase()}`"
      >
        {{ status }}
      </span>
    </div>
    
    <div class="details" v-if="lastUpdate">
      <p class="last-update">
        Last Updated: {{ formatDate(lastUpdate) }}
      </p>
    </div>
    
    <div class="metrics" v-if="metrics">
      <div class="metric">
        <span class="metric-label">Size:</span>
        <span class="metric-value">{{ metrics.size || 'N/A' }}</span>
      </div>
      <div class="metric">
        <span class="metric-label">Files:</span>
        <span class="metric-value">{{ metrics.files || 'N/A' }}</span>
      </div>
      <div class="metric">
        <span class="metric-label">Disk Usage:</span>
        <span class="metric-value">{{ metrics.diskUsage || 'N/A' }}</span>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'MirrorCard',
  props: {
    title: {
      type: String,
      required: true
    },
    status: {
      type: String,
      default: 'UNKNOWN'
    },
    lastUpdate: {
      type: Date,
      default: null
    },
    metrics: {
      type: Object,
      default: null
    }
  },
  methods: {
    formatDate(date) {
      if (!date) return 'Never'
      return new Intl.DateTimeFormat('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      }).format(date)
    }
  }
}
</script>

<style scoped>
.mirror-card {
  border-left: 4px solid #667eea;
}

.status-section {
  margin: 15px 0;
}

.details {
  margin-top: 15px;
  padding-top: 15px;
  border-top: 1px solid #e0e6ed;
}

.last-update {
  font-size: 0.9rem;
  color: #6c757d;
}

.metrics {
  margin-top: 15px;
  padding-top: 15px;
  border-top: 1px solid #e0e6ed;
}

.metric {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
}

.metric-label {
  font-weight: 500;
  color: #495057;
}

.metric-value {
  color: #6c757d;
  font-family: monospace;
}
</style>