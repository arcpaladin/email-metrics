module.exports = {
  apps: [{
    name: 'email-analytics',
    script: 'server.js',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log'
  }],

  deploy: {
    production: {
      user: 'ubuntu',
      host: '3.129.68.100',  // Auto-updated by deploy script
      ref: 'origin/main',
      repo: 'https://github.com/arcpaladin/email-metrics.git',
      path: '/home/ubuntu/deployment',
      key: './email-analytics.pem',
      'pre-deploy-local': '',
      'post-deploy': 'cd /home/ubuntu/deployment/current && cp deploy/* . && npm install && pm2 startOrRestart ecosystem.config.js --env production',
      'pre-setup': 'mkdir -p /home/ubuntu/deployment && mkdir -p /home/ubuntu/deployment/shared/logs'
    }
  }
}
;
