const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const compression = require("compression");
const morgan = require("morgan");
require("dotenv").config();

const userRoutes = require("./routes/users");
const { initDatabase } = require("./config/database");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(
  cors({
    origin: process.env.ALLOWED_ORIGINS?.split(",") || [
      "http://localhost:3000",
    ],
    credentials: true,
  })
);

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: {
    error: "Muitas requisições deste IP, tente novamente em 15 minutos.",
  },
});
app.use(limiter);

app.use(compression());
app.use(morgan("combined"));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

initDatabase();

app.use("/api/users", userRoutes);

app.get("/health", (req, res) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || "development",
  });
});

app.get("/", (req, res) => {
  res.json({
    message: "ExpertAI API - Sistema de Gerenciamento de Usuários",
    version: "1.0.0",
    docs: "/api/users",
    health: "/health",
  });
});

app.use((err, req, res, next) => {
  console.error("Erro:", err.stack);

  if (err.type === "entity.parse.failed") {
    return res.status(400).json({
      error: "Dados JSON inválidos",
    });
  }

  res.status(err.status || 500).json({
    error:
      process.env.NODE_ENV === "production"
        ? "Erro interno do servidor"
        : err.message,
  });
});

app.use("*", (req, res) => {
  res.status(404).json({
    error: "Rota não encontrada",
    path: req.originalUrl,
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 Servidor ExpertAI rodando na porta ${PORT}`);
  console.log(`📊 Ambiente: ${process.env.NODE_ENV || "development"}`);
  console.log(`🔗 URL: http://localhost:${PORT}`);
});

process.on("SIGTERM", () => {
  console.log("🛑 Recebido SIGTERM, encerrando servidor...");
  process.exit(0);
});

process.on("SIGINT", () => {
  console.log("🛑 Recebido SIGINT, encerrando servidor...");
  process.exit(0);
});

module.exports = app;
