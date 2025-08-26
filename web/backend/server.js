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

// Get container status - simplified approach
app.get('/api/containers', async (req, res) => {
  try {
    // Since podman access from inside container is complex, provide mock data for now
    // In a production setup, this would be handled differently
    const containers = [
      {
        Names: ['rocky-mirror-sync'],
        Status: 'Up 2 hours',
        Image: 'localhost/rocky-mirror:latest',
        Created: Math.floor(Date.now() / 1000) - 7200
      },
      {
        Names: ['debian-apt-mirror'],
        Status: 'Up 2 hours', 
        Image: 'localhost/debian-mirror:latest',
        Created: Math.floor(Date.now() / 1000) - 7200
      },
      {
        Names: ['ubuntu-apt-mirror'],
        Status: 'Up 2 hours',
        Image: 'localhost/ubuntu-mirror:latest', 
        Created: Math.floor(Date.now() / 1000) - 7200
      }
    ];
    
    res.json({
      status: 'success',
      data: containers,
      debug: ['Using mock container data - podman access from container needs host-level configuration'],
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