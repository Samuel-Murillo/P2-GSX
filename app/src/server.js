const http = require('http');
const { Client } = require('pg');
const os = require('os');

const port = process.env.PORT || 3000;

const server = http.createServer(async (req, res) => {
  // Health check endpoint: responde inmediatamente sin tocar la DB.
  // Los liveness/readiness probes de Kubernetes apuntan aquí.
  if (req.url === '/health') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain');
    res.end('OK\n');
    return;
  }

  // Ruta principal: demuestra el flujo completo Nginx → App → DB
  let dbTime = "Error al conectar con la base de datos";
  let dbStatus = "FAILED";

  const client = new Client({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
  });

  try {
    await client.connect();
    const result = await client.query('SELECT NOW()');
    dbTime = result.rows[0].now;
    dbStatus = "OK";
    await client.end();
  } catch (err) {
    console.error('Database connection error:', err.message);
  }

  const localTime = new Date().toISOString();

  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end(
    `=== GreenDevCorp Backend ===\n` +
    `Hostname (pod): ${os.hostname()}\n` +
    `Hora del servidor (local): ${localTime}\n` +
    `\n` +
    `=== Conexión a Base de Datos ===\n` +
    `Estado: ${dbStatus}\n` +
    `DB Host: ${process.env.DB_HOST || 'no configurado'}:${process.env.DB_PORT || '5432'}\n` +
    `DB Time (PostgreSQL NOW()): ${dbTime}\n`
  );
});

server.listen(port, () => {
  console.log(`Server running at port ${port}/`);
});
