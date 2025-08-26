const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

const PROJECT_ROOT = process.env.PROJECT_ROOT || '/app/mirror-sync';
const PORT = process.env.PORT || 3001;

// Utility function to execute shell commands with timeout
const executeCommand = (command, cwd = PROJECT_ROOT, timeoutMs = 30000) => {
  return new Promise((resolve, reject) => {
    const child = exec(command, { cwd, timeout: timeoutMs }, (error, stdout, stderr) => {
      if (error) {
        reject({ error: error.message, stderr });
      } else {
        resolve({ stdout, stderr });
      }
    });
    
    // Additional timeout safety
    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      reject({ error: `Command timeout after ${timeoutMs}ms`, stderr: '' });
    }, timeoutMs);
    
    child.on('exit', () => {
      clearTimeout(timer);
    });
  });
};

// API Routes

// Get overall mirror status
app.get('/api/status', async (req, res) => {
  try {
    console.log('Executing monitor script from:', PROJECT_ROOT);
    const result = await executeCommand('./scripts/monitor-mirrors.sh check');
    console.log('Monitor script output:', result.stdout.substring(0, 200));
    
    res.json({
      status: 'success',
      data: result.stdout,
      debug: {
        projectRoot: PROJECT_ROOT,
        workingDir: process.cwd(),
        outputLength: result.stdout.length
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Monitor script error:', error);
    res.status(500).json({
      status: 'error',
      message: error.error || 'Failed to get mirror status',
      debug: {
        projectRoot: PROJECT_ROOT,
        workingDir: process.cwd(),
        stderr: error.stderr
      }
    });
  }
});

// Get detailed status report
app.get('/api/report', async (req, res) => {
  try {
    const result = await executeCommand('./scripts/monitor-mirrors.sh report');
    
    // Also read the generated report file
    const reportPath = path.join(PROJECT_ROOT, 'logs/mirror-status-report.txt');
    let reportContent = '';
    
    try {
      reportContent = fs.readFileSync(reportPath, 'utf8');
    } catch (readError) {
      console.warn('Could not read report file:', readError.message);
    }
    
    res.json({
      status: 'success',
      data: {
        output: result.stdout,
        report: reportContent
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.error || 'Failed to generate report'
    });
  }
});

// Get container status
app.get('/api/containers', async (req, res) => {
  try {
    let containers = [];
    let debugInfo = [];
    
    // Try podman first (since that's what's running on the host)
    try {
      const podmanResult = await executeCommand('podman ps --format "json"');
      debugInfo.push(`Podman command succeeded, output length: ${podmanResult.stdout.length}`);
      
      if (podmanResult.stdout.trim()) {
        const allContainers = podmanResult.stdout.trim().split('\n').map(line => {
          try {
            return JSON.parse(line);
          } catch (e) {
            debugInfo.push(`JSON parse error: ${e.message} for line: ${line.substring(0, 100)}`);
            return null;
          }
        }).filter(container => container);
        
        debugInfo.push(`Total containers found: ${allContainers.length}`);
        
        // Filter for mirror-related containers - check both Names and container name patterns
        containers = allContainers.filter(container => {
          const name = container.Names ? container.Names[0] : '';
          const imageName = container.Image || '';
          const isMirrorContainer = name.includes('mirror') || 
                                   imageName.includes('mirror') ||
                                   name.includes('debian') ||
                                   name.includes('ubuntu') ||
                                   name.includes('rocky');
          
          if (isMirrorContainer) {
            debugInfo.push(`Found mirror container: ${name} (${imageName})`);
          }
          
          return isMirrorContainer;
        });
      }
    } catch (podmanError) {
      debugInfo.push(`Podman failed: ${podmanError.error || podmanError.message}`);
      
      // Fallback to docker
      try {
        const dockerResult = await executeCommand('docker ps --format "json"');
        debugInfo.push(`Docker command succeeded`);
        // Similar processing for docker...
      } catch (dockerError) {
        debugInfo.push(`Docker also failed: ${dockerError.error || dockerError.message}`);
      }
    }
    
    res.json({
      status: 'success',
      data: containers,
      debug: debugInfo,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.error || 'Failed to get container status',
      debug: error.stderr || error.message
    });
  }
});

// Get logs
app.get('/api/logs/:type?', async (req, res) => {
  try {
    const logType = req.params.type || 'monitor';
    const lines = req.query.lines || '100';
    
    const logsDir = path.join(PROJECT_ROOT, 'logs');
    const logFiles = fs.readdirSync(logsDir)
      .filter(file => file.includes(logType) && file.endsWith('.log'))
      .sort((a, b) => {
        const statsA = fs.statSync(path.join(logsDir, a));
        const statsB = fs.statSync(path.join(logsDir, b));
        return statsB.mtime - statsA.mtime;
      });
    
    if (logFiles.length === 0) {
      return res.json({
        status: 'success',
        data: [],
        message: `No ${logType} logs found`
      });
    }
    
    const latestLogFile = path.join(logsDir, logFiles[0]);
    const result = await executeCommand(`tail -${lines} "${latestLogFile}"`);
    
    const logs = result.stdout.split('\n')
      .filter(line => line.trim())
      .map(line => {
        const match = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+\[(\w+)\]\s+(.*)$/);
        if (match) {
          return {
            timestamp: match[1],
            level: match[2],
            message: match[3]
          };
        }
        return {
          timestamp: null,
          level: 'INFO',
          message: line
        };
      });
    
    res.json({
      status: 'success',
      data: logs,
      file: logFiles[0],
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.error || 'Failed to get logs'
    });
  }
});

// WebSocket connection handling
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  
  // Send initial status
  socket.emit('status', { message: 'Connected to Mirror Sync API' });
  
  // Handle real-time monitoring requests
  socket.on('startMonitoring', () => {
    console.log('Client requested real-time monitoring');
    
    // Send status updates every 30 seconds
    const interval = setInterval(async () => {
      try {
        const result = await executeCommand('./scripts/monitor-mirrors.sh check');
        socket.emit('statusUpdate', {
          status: 'success',
          data: result.stdout,
          timestamp: new Date().toISOString()
        });
      } catch (error) {
        socket.emit('statusUpdate', {
          status: 'error',
          message: error.error || 'Failed to get status update',
          timestamp: new Date().toISOString()
        });
      }
    }, 30000);
    
    socket.on('disconnect', () => {
      clearInterval(interval);
      console.log('Client disconnected:', socket.id);
    });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Mirror Sync API server running on port ${PORT}`);
  console.log(`Project root: ${PROJECT_ROOT}`);
});