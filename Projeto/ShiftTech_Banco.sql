/* =====================================================================
   ShiftTech - Sistema de Oficina Mecânica
   Script do banco de dados (SQL Server / SQL Server Express)

   Banco usado pelo projeto: ProjetoMVC
   (conexão em Services/DataBaseSqlServer.cs -> .\SQLEXPRESS)

   Os nomes de tabelas e colunas seguem exatamente o que os
   Controllers do projeto usam nas consultas.

   O script pode ser executado mais de uma vez: ele só cria o que
   ainda não existe e só insere os dados de exemplo se as tabelas
   estiverem vazias.
   ===================================================================== */

IF DB_ID('ProjetoMVC') IS NULL
    CREATE DATABASE ProjetoMVC;
GO

USE ProjetoMVC;
GO

/* =====================================================================
   1. TABELAS
   ===================================================================== */

-- ---------------------------------------------------------------------
-- USUÁRIOS (funcionários que usam o sistema)
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.Usuario', 'U') IS NULL
CREATE TABLE Usuario
(
    usuario_id  INT IDENTITY(1,1) NOT NULL,
    nome        VARCHAR(250) NOT NULL,
    email       VARCHAR(250) NOT NULL,
    senha       VARCHAR(250) NOT NULL,
    cpf         VARCHAR(14)  NOT NULL,   -- 000.000.000-00
    telefone    VARCHAR(20)  NOT NULL,
    cargo       VARCHAR(50)  NOT NULL,

    CONSTRAINT PK_Usuario PRIMARY KEY (usuario_id)
);
GO

-- ---------------------------------------------------------------------
-- CLIENTES
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.Cliente', 'U') IS NULL
CREATE TABLE Cliente
(
    cliente_id  INT IDENTITY(1,1) NOT NULL,
    nome        VARCHAR(250) NOT NULL,
    cpf         VARCHAR(18)  NOT NULL,   -- CPF (14) ou CNPJ formatado (18)
    qt_veiculos INT          NOT NULL CONSTRAINT DF_Cliente_QtVeiculos DEFAULT 0,
    telefone    VARCHAR(20)  NOT NULL,
    email       VARCHAR(250) NULL,
    cep         INT          NOT NULL,   -- o model Cliente usa int para o CEP
    endereco    VARCHAR(250) NOT NULL,
    cidade      VARCHAR(100) NOT NULL,

    CONSTRAINT PK_Cliente PRIMARY KEY (cliente_id),
    CONSTRAINT CK_Cliente_QtVeiculos CHECK (qt_veiculos >= 0)
);
GO

-- ---------------------------------------------------------------------
-- VEÍCULOS (cada veículo pertence a um cliente)
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.Veiculo', 'U') IS NULL
CREATE TABLE Veiculo
(
    veiculo_id  INT IDENTITY(1,1) NOT NULL,
    cliente_id  INT          NOT NULL,
    placa       VARCHAR(10)  NOT NULL,
    marca       VARCHAR(100) NOT NULL,
    modelo      VARCHAR(100) NOT NULL,
    ano         INT          NOT NULL,
    cor         VARCHAR(50)  NULL,
    motor       VARCHAR(50)  NULL,
    combustivel VARCHAR(30)  NULL,

    CONSTRAINT PK_Veiculo PRIMARY KEY (veiculo_id),

    -- Sem ON DELETE CASCADE de propósito: a tela de clientes trata o
    -- erro 547 para avisar que o cliente ainda tem veículos.
    CONSTRAINT FK_Veiculo_Cliente FOREIGN KEY (cliente_id)
        REFERENCES Cliente (cliente_id)
);
GO

-- ---------------------------------------------------------------------
-- ORDENS DE SERVIÇO
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.OrdemServico', 'U') IS NULL
CREATE TABLE OrdemServico
(
    ordem_servico_id   INT IDENTITY(1,1) NOT NULL,
    cliente_id         INT           NOT NULL,
    veiculo_id         INT           NOT NULL,
    data_abertura      DATETIME      NOT NULL CONSTRAINT DF_OrdemServico_Abertura DEFAULT GETDATE(),
    data_previsao      DATETIME      NULL,
    data_fechamento    DATETIME      NULL,
    status             VARCHAR(50)   NOT NULL,  -- Aberta, Em andamento, Aguardando peças,
                                                -- Aguardando aprovação, Concluída, Entregue, Cancelada
    descricao_problema VARCHAR(500)  NOT NULL,
    diagnostico        VARCHAR(500)  NOT NULL,
    observacoes        VARCHAR(500)  NOT NULL,
    valor_mao_obra     DECIMAL(10,2) NOT NULL CONSTRAINT DF_OrdemServico_MaoObra DEFAULT 0,
    valor_total        DECIMAL(10,2) NOT NULL CONSTRAINT DF_OrdemServico_Total   DEFAULT 0,

    CONSTRAINT PK_OrdemServico PRIMARY KEY (ordem_servico_id),

    -- Sem cascade: a tela de veículos trata o erro 547 quando o veículo
    -- possui ordens de serviço.
    CONSTRAINT FK_OrdemServico_Cliente FOREIGN KEY (cliente_id)
        REFERENCES Cliente (cliente_id),
    CONSTRAINT FK_OrdemServico_Veiculo FOREIGN KEY (veiculo_id)
        REFERENCES Veiculo (veiculo_id),

    CONSTRAINT CK_OrdemServico_Valores CHECK (valor_mao_obra >= 0 AND valor_total >= 0)
);
GO

-- ---------------------------------------------------------------------
-- ITENS DA ORDEM DE SERVIÇO (peças e serviços)
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.OrdemServicoItem', 'U') IS NULL
CREATE TABLE OrdemServicoItem
(
    item_id          INT IDENTITY(1,1) NOT NULL,
    ordem_servico_id INT           NOT NULL,
    tipo             VARCHAR(50)   NOT NULL,   -- Peça ou Serviço
    descricao        VARCHAR(250)  NOT NULL,
    quantidade       DECIMAL(10,2) NOT NULL,
    valor_unitario   DECIMAL(10,2) NOT NULL,
    subtotal         DECIMAL(10,2) NOT NULL,   -- quantidade * valor_unitario

    CONSTRAINT PK_OrdemServicoItem PRIMARY KEY (item_id),
    CONSTRAINT FK_OrdemServicoItem_OS FOREIGN KEY (ordem_servico_id)
        REFERENCES OrdemServico (ordem_servico_id)
        ON DELETE CASCADE,

    CONSTRAINT CK_OrdemServicoItem_Valores
        CHECK (quantidade >= 0 AND valor_unitario >= 0 AND subtotal >= 0)
);
GO

-- ---------------------------------------------------------------------
-- HISTÓRICO DE STATUS DA ORDEM DE SERVIÇO
-- (preenchido pelo OrdemServicoController ao cadastrar/alterar status)
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.OrdemServicoHistorico', 'U') IS NULL
CREATE TABLE OrdemServicoHistorico
(
    historico_id     INT IDENTITY(1,1) NOT NULL,
    ordem_servico_id INT         NOT NULL,
    status_anterior  VARCHAR(50) NOT NULL,   -- "Cadastro" na abertura da OS
    status_novo      VARCHAR(50) NOT NULL,
    data_alteracao   DATETIME    NOT NULL CONSTRAINT DF_Historico_Data DEFAULT GETDATE(),

    CONSTRAINT PK_OrdemServicoHistorico PRIMARY KEY (historico_id),
    CONSTRAINT FK_Historico_OS FOREIGN KEY (ordem_servico_id)
        REFERENCES OrdemServico (ordem_servico_id)
        ON DELETE CASCADE
);
GO

/* =====================================================================
   2. ÍNDICES (deixam as buscas e os JOINs mais rápidos)
   ===================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Cliente_Nome')
    CREATE INDEX IX_Cliente_Nome ON Cliente (nome);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Veiculo_Cliente')
    CREATE INDEX IX_Veiculo_Cliente ON Veiculo (cliente_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Veiculo_Placa')
    CREATE INDEX IX_Veiculo_Placa ON Veiculo (placa);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrdemServico_Cliente')
    CREATE INDEX IX_OrdemServico_Cliente ON OrdemServico (cliente_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrdemServico_Veiculo')
    CREATE INDEX IX_OrdemServico_Veiculo ON OrdemServico (veiculo_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrdemServico_Status')
    CREATE INDEX IX_OrdemServico_Status ON OrdemServico (status);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrdemServicoItem_OS')
    CREATE INDEX IX_OrdemServicoItem_OS ON OrdemServicoItem (ordem_servico_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Historico_OS')
    CREATE INDEX IX_Historico_OS ON OrdemServicoHistorico (ordem_servico_id);
GO

/* =====================================================================
   3. TRIGGER - mantém Cliente.qt_veiculos sempre atualizado
      sempre que um veículo é cadastrado, alterado ou excluído.
   ===================================================================== */

CREATE OR ALTER TRIGGER TR_Veiculo_AtualizaQtVeiculos
ON Veiculo
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE C
    SET qt_veiculos = (SELECT COUNT(*) FROM Veiculo V WHERE V.cliente_id = C.cliente_id)
    FROM Cliente C
    WHERE C.cliente_id IN (SELECT cliente_id FROM inserted
                           UNION
                           SELECT cliente_id FROM deleted);
END;
GO

/* =====================================================================
   4. VIEWS (consultas prontas para relatórios)
   ===================================================================== */

-- Ordens de serviço com nome do cliente e descrição do veículo
-- (mesmo formato usado pelo OrdemServicoController)
CREATE OR ALTER VIEW vw_OrdemServicoCompleta
AS
SELECT
    OS.ordem_servico_id,
    OS.data_abertura,
    OS.data_previsao,
    OS.data_fechamento,
    OS.status,
    C.cliente_id,
    C.nome                                       AS cliente_nome,
    C.telefone                                   AS cliente_telefone,
    V.veiculo_id,
    V.marca + ' ' + V.modelo + ' - ' + V.placa   AS veiculo_descricao,
    OS.descricao_problema,
    OS.diagnostico,
    OS.valor_mao_obra,
    ISNULL(I.total_pecas, 0)                     AS total_pecas,
    ISNULL(I.total_servicos, 0)                  AS total_servicos,
    OS.valor_total
FROM OrdemServico OS
INNER JOIN Cliente C ON C.cliente_id = OS.cliente_id
INNER JOIN Veiculo V ON V.veiculo_id = OS.veiculo_id
LEFT JOIN
(
    SELECT
        ordem_servico_id,
        SUM(CASE WHEN tipo = 'Peça'    THEN subtotal ELSE 0 END) AS total_pecas,
        SUM(CASE WHEN tipo = 'Serviço' THEN subtotal ELSE 0 END) AS total_servicos
    FROM OrdemServicoItem
    GROUP BY ordem_servico_id
) I ON I.ordem_servico_id = OS.ordem_servico_id;
GO

-- Veículos com o nome do dono e quantas OS cada um já teve
CREATE OR ALTER VIEW vw_VeiculoCliente
AS
SELECT
    V.veiculo_id,
    V.placa,
    V.marca,
    V.modelo,
    V.ano,
    V.cor,
    V.combustivel,
    C.cliente_id,
    C.nome AS cliente_nome,
    (SELECT COUNT(*) FROM OrdemServico OS WHERE OS.veiculo_id = V.veiculo_id) AS qt_ordens
FROM Veiculo V
INNER JOIN Cliente C ON C.cliente_id = V.cliente_id;
GO

/* =====================================================================
   5. DADOS DE EXEMPLO (só são inseridos se as tabelas estiverem vazias)
   ===================================================================== */

IF NOT EXISTS (SELECT 1 FROM Usuario)
BEGIN
    INSERT INTO Usuario (nome, email, senha, cpf, telefone, cargo) VALUES
    ('Administrador',   'admin@shifttech.com',  'admin123', '111.111.111-11', '(11) 99999-0000', 'Administrador'),
    ('Carlos Mendes',   'carlos@shifttech.com', '123456',   '222.222.222-22', '(11) 98888-1111', 'Mecânico'),
    ('Fernanda Rocha',  'fernanda@shifttech.com','123456',  '333.333.333-33', '(11) 97777-2222', 'Atendente');
END;
GO

IF NOT EXISTS (SELECT 1 FROM Cliente)
BEGIN
    INSERT INTO Cliente (nome, cpf, telefone, email, cep, endereco, cidade) VALUES
    ('João da Silva',     '123.456.789-00', '(11) 91234-5678', 'joao@email.com',   1310100, 'Av. Paulista, 1000',      'São Paulo'),
    ('Maria Oliveira',    '987.654.321-00', '(11) 92345-6789', 'maria@email.com',  4538133, 'Rua Funchal, 250',        'São Paulo'),
    ('Pedro Santos',      '456.789.123-00', '(19) 93456-7890', NULL,               13010111,'Rua Barão de Jaguara, 50','Campinas'),
    ('Transportes Rápido Ltda', '12.345.678/0001-90', '(11) 3333-4444', 'frota@rapido.com', 6454000, 'Al. Rio Negro, 500', 'Barueri');
END;
GO

IF NOT EXISTS (SELECT 1 FROM Veiculo)
BEGIN
    -- qt_veiculos dos clientes é atualizado automaticamente pelo trigger
    INSERT INTO Veiculo (cliente_id, placa, marca, modelo, ano, cor, motor, combustivel) VALUES
    (1, 'ABC1D23', 'Volkswagen', 'Gol',      2018, 'Prata',  '1.0', 'Flex'),
    (1, 'DEF4G56', 'Honda',      'Civic',    2020, 'Preto',  '2.0', 'Flex'),
    (2, 'GHI7J89', 'Chevrolet',  'Onix',     2022, 'Branco', '1.0 Turbo', 'Flex'),
    (3, 'JKL0M12', 'Fiat',       'Strada',   2019, 'Vermelho','1.4', 'Flex'),
    (4, 'MNO3P45', 'Mercedes',   'Sprinter', 2021, 'Branco', '2.2', 'Diesel');
END;
GO

IF NOT EXISTS (SELECT 1 FROM OrdemServico)
BEGIN
    INSERT INTO OrdemServico
        (cliente_id, veiculo_id, data_abertura, data_previsao, data_fechamento, status,
         descricao_problema, diagnostico, observacoes, valor_mao_obra, valor_total)
    VALUES
    (1, 1, '20261102 08:30', '20261104 18:00', '20261104 16:00', 'Entregue',
     'Barulho ao frear', 'Pastilhas de freio dianteiras gastas', 'Cliente retirou o carro', 120.00, 380.00),

    (2, 3, '20261105 09:00', '20261107 18:00', NULL, 'Em andamento',
     'Revisão dos 30.000 km', 'Troca de óleo, filtros e alinhamento', '', 150.00, 449.80),

    (3, 4, '20261108 14:00', '20261112 18:00', NULL, 'Aguardando peças',
     'Carro esquentando', 'Bomba d''água com vazamento', 'Peça encomendada', 200.00, 200.00),

    (4, 5, '20261110 10:15', NULL, NULL, 'Aberta',
     'Luz de injeção acesa', '', '', 0.00, 0.00);

    INSERT INTO OrdemServicoItem
        (ordem_servico_id, tipo, descricao, quantidade, valor_unitario, subtotal)
    VALUES
    (1, 'Peça',    'Jogo de pastilhas de freio dianteiras', 1, 180.00, 180.00),
    (1, 'Serviço', 'Retífica dos discos de freio',          2,  40.00,  80.00),

    (2, 'Peça',    'Óleo 5W30 sintético (litro)',           4,  45.00, 180.00),
    (2, 'Peça',    'Filtro de óleo',                        1,  39.90,  39.90),
    (2, 'Peça',    'Filtro de ar',                          1,  29.90,  29.90),
    (2, 'Serviço', 'Alinhamento e balanceamento',           1,  50.00,  50.00);

    -- Histórico no mesmo formato gerado pelo sistema
    INSERT INTO OrdemServicoHistorico (ordem_servico_id, status_anterior, status_novo, data_alteracao) VALUES
    (1, 'Cadastro',     'Aberta',           '20261102 08:30'),
    (1, 'Aberta',       'Em andamento',     '20261102 10:00'),
    (1, 'Em andamento', 'Concluída',        '20261104 15:00'),
    (1, 'Concluída',    'Entregue',         '20261104 16:00'),
    (2, 'Cadastro',     'Aberta',           '20261105 09:00'),
    (2, 'Aberta',       'Em andamento',     '20261105 11:00'),
    (3, 'Cadastro',     'Aberta',           '20261108 14:00'),
    (3, 'Aberta',       'Aguardando peças', '20261108 16:30'),
    (4, 'Cadastro',     'Aberta',           '20261110 10:15');
END;
GO

/* =====================================================================
   6. CONSULTAS DE EXEMPLO (para testar / apresentar o trabalho)
   ===================================================================== */

-- Todas as OS com cliente e veículo
SELECT * FROM vw_OrdemServicoCompleta ORDER BY data_abertura DESC;

-- OS que ainda não foram finalizadas
SELECT ordem_servico_id, cliente_nome, veiculo_descricao, status, data_previsao
FROM vw_OrdemServicoCompleta
WHERE status NOT IN ('Concluída', 'Entregue', 'Cancelada')
ORDER BY data_previsao;

-- OS atrasadas (previsão já passou e não foi fechada)
SELECT ordem_servico_id, cliente_nome, veiculo_descricao, status, data_previsao
FROM vw_OrdemServicoCompleta
WHERE data_fechamento IS NULL
  AND data_previsao < GETDATE()
  AND status <> 'Cancelada';

-- Faturamento por mês (OS entregues ou concluídas)
SELECT
    YEAR(data_fechamento)  AS ano,
    MONTH(data_fechamento) AS mes,
    COUNT(*)               AS qt_ordens,
    SUM(valor_total)       AS faturamento
FROM OrdemServico
WHERE status IN ('Concluída', 'Entregue')
  AND data_fechamento IS NOT NULL
GROUP BY YEAR(data_fechamento), MONTH(data_fechamento)
ORDER BY ano, mes;

-- Clientes com a quantidade de veículos e o total já gasto na oficina
SELECT
    C.cliente_id,
    C.nome,
    C.qt_veiculos,
    COUNT(OS.ordem_servico_id)   AS qt_ordens,
    ISNULL(SUM(OS.valor_total),0) AS total_gasto
FROM Cliente C
LEFT JOIN OrdemServico OS ON OS.cliente_id = C.cliente_id
GROUP BY C.cliente_id, C.nome, C.qt_veiculos
ORDER BY total_gasto DESC;

-- Peças mais usadas
SELECT descricao, SUM(quantidade) AS qt_total, SUM(subtotal) AS valor_total
FROM OrdemServicoItem
WHERE tipo = 'Peça'
GROUP BY descricao
ORDER BY qt_total DESC;

-- Histórico completo de uma OS
SELECT status_anterior, status_novo, data_alteracao
FROM OrdemServicoHistorico
WHERE ordem_servico_id = 1
ORDER BY data_alteracao;
GO
