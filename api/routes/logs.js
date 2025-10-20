const express = require("express");
const Joi = require("joi");
const fs = require("fs");
const path = require("path");

const router = express.Router();

const LOG_DIR = process.env.LOG_DIR || "/var/log";
const ACCESS_LOG = path.join(LOG_DIR, "xp_access.log");
const OPERATION_LOG = path.join(LOG_DIR, "xp_operation.log");

const ensureLogDirectory = () => {
  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true, mode: 0o755 });
  }

  [ACCESS_LOG, OPERATION_LOG].forEach((logFile) => {
    if (!fs.existsSync(logFile)) {
      fs.writeFileSync(logFile, "", { mode: 0o644 });
    }
  });
};

ensureLogDirectory();

const accessLogSchema = Joi.object({
  timestamp: Joi.string().isoDate().optional(),
  user: Joi.string().required(),
  ip: Joi.string().ip().optional(),
  action: Joi.string().required(),
  resource: Joi.string().required(),
  status: Joi.string().valid("SUCCESS", "FAILURE", "WARNING").required(),
  details: Joi.string().optional(),
});

const operationLogSchema = Joi.object({
  timestamp: Joi.string().isoDate().optional(),
  user: Joi.string().required(),
  operation: Joi.string().required(),
  target: Joi.string().optional(),
  status: Joi.string()
    .valid("STARTED", "COMPLETED", "FAILED", "IN_PROGRESS")
    .required(),
  duration_ms: Joi.number().optional(),
  records_affected: Joi.number().optional(),
  details: Joi.string().optional(),
});

const formatLogEntry = (data) => {
  const timestamp = data.timestamp || new Date().toISOString();
  return `[${timestamp}] [${data.user}] [${
    data.status || data.operation
  }] ${JSON.stringify(data)}\n`;
};

const writeLog = (logFile, data) => {
  return new Promise((resolve, reject) => {
    const logEntry = formatLogEntry(data);
    fs.appendFile(logFile, logEntry, (err) => {
      if (err) {
        console.error(`Erro ao escrever log em ${logFile}:`, err);
        reject(err);
      } else {
        resolve();
      }
    });
  });
};

router.post("/access", async (req, res) => {
  try {
    const { error, value } = accessLogSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: "Dados inválidos",
        details: error.details.map((detail) => detail.message),
      });
    }

    if (!value.ip) {
      value.ip = req.ip || req.connection.remoteAddress;
    }

    await writeLog(ACCESS_LOG, value);

    res.status(201).json({
      message: "Log de acesso registrado com sucesso",
      timestamp: value.timestamp || new Date().toISOString(),
    });
  } catch (error) {
    console.error("Erro ao registrar log de acesso:", error);
    res.status(500).json({ error: "Erro interno ao registrar log" });
  }
});

router.post("/operation", async (req, res) => {
  try {
    const { error, value } = operationLogSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: "Dados inválidos",
        details: error.details.map((detail) => detail.message),
      });
    }

    await writeLog(OPERATION_LOG, value);

    res.status(201).json({
      message: "Log de operação registrado com sucesso",
      timestamp: value.timestamp || new Date().toISOString(),
    });
  } catch (error) {
    console.error("Erro ao registrar log de operação:", error);
    res.status(500).json({ error: "Erro interno ao registrar log" });
  }
});

router.get("/access", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 100;

    if (!fs.existsSync(ACCESS_LOG)) {
      return res.json({ data: [], count: 0 });
    }

    const content = fs.readFileSync(ACCESS_LOG, "utf-8");
    const lines = content
      .trim()
      .split("\n")
      .filter((line) => line);

    const recentLogs = lines.slice(-limit);

    res.json({
      data: recentLogs,
      count: recentLogs.length,
      total: lines.length,
    });
  } catch (error) {
    console.error("Erro ao ler logs de acesso:", error);
    res.status(500).json({ error: "Erro ao ler logs" });
  }
});

router.get("/operation", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 100;

    if (!fs.existsSync(OPERATION_LOG)) {
      return res.json({ data: [], count: 0 });
    }

    const content = fs.readFileSync(OPERATION_LOG, "utf-8");
    const lines = content
      .trim()
      .split("\n")
      .filter((line) => line);

    const recentLogs = lines.slice(-limit);

    res.json({
      data: recentLogs,
      count: recentLogs.length,
      total: lines.length,
    });
  } catch (error) {
    console.error("Erro ao ler logs de operação:", error);
    res.status(500).json({ error: "Erro ao ler logs" });
  }
});

router.get("/health", (req, res) => {
  const status = {
    log_directory: LOG_DIR,
    access_log: {
      path: ACCESS_LOG,
      exists: fs.existsSync(ACCESS_LOG),
      writable: false,
    },
    operation_log: {
      path: OPERATION_LOG,
      exists: fs.existsSync(OPERATION_LOG),
      writable: false,
    },
  };

  try {
    fs.accessSync(ACCESS_LOG, fs.constants.W_OK);
    status.access_log.writable = true;
  } catch (err) {}

  try {
    fs.accessSync(OPERATION_LOG, fs.constants.W_OK);
    status.operation_log.writable = true;
  } catch (err) {}

  res.json(status);
});

module.exports = router;
