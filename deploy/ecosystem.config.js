module.exports = {
  apps: [{
    name: 'email-analytics-api',
    script: 'server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 80
    },
    error_file: '/var/log/pm2/email-analytics-error.log',
    out_file: '/var/log/pm2/email-analytics-out.log',
    log_file: '/var/log/pm2/email-analytics-combined.log',
    time: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    kill_timeout: 5000,
    restart_delay: 1000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
