USE RRT;
GO

-- 1. Abonentas: atributas "nuolaida" 
IF OBJECT_ID('DF_Abonentas_nuolaida', 'D') IS NOT NULL
    ALTER TABLE Abonentas DROP CONSTRAINT DF_Abonentas_nuolaida;
IF COL_LENGTH('Abonentas', 'nuolaida') IS NOT NULL
    ALTER TABLE Abonentas DROP COLUMN nuolaida;

ALTER TABLE Abonentas
ADD nuolaida DECIMAL(3, 2) NOT NULL
    CONSTRAINT DF_Abonentas_nuolaida DEFAULT 0.00;

EXEC('SELECT TOP 10 abonentoID, numeris, nuolaida FROM Abonentas');   -- EXEC, nes stulpelis sukurtas tame pačiame bloke
GO

-- 2. Asmuo: atributas "elPastas" 
IF COL_LENGTH('Asmuo', 'elPastas') IS NOT NULL
    ALTER TABLE Asmuo DROP COLUMN elPastas;

ALTER TABLE Asmuo
ADD elPastas VARCHAR(50) NULL;

EXEC('SELECT TOP 10 asmensID, vardas, pavarde, elPastas FROM Asmuo');   -- EXEC, nes stulpelis sukurtas tame pačiame bloke
GO

-- 3. Lentelė Domenas
DROP TABLE IF EXISTS Domenas;

CREATE TABLE Domenas (
    domenoID    INT IDENTITY(1, 1) PRIMARY KEY,
    pavadinimas VARCHAR(15)
);

SELECT * FROM Domenas;
GO

-- 4. Domenų įrašai
TRUNCATE TABLE Domenas;   -- išvalo ankstesnius įrašus ir domenoID vėl pradeda nuo 1

INSERT INTO Domenas (pavadinimas)
VALUES ('gmail.com'), ('yahoo.com'), ('hotmail.com'), ('eif.viko.lt');

SELECT * FROM Domenas;
GO

-- 5. Asmenų el. paštas: vardas.pavarde@atsitiktinis_domenas
--   
UPDATE a
SET a.elPastas = LOWER(RTRIM(a.vardas)) + '.' + LOWER(RTRIM(a.pavarde)) + '@' + d.pavadinimas
FROM Asmuo a
CROSS APPLY (
    SELECT TOP 1 pavadinimas
    FROM Domenas
    WHERE a.asmensID IS NOT NULL
    ORDER BY NEWID()
) d;

SELECT TOP 10 vardas, pavarde, elPastas FROM Asmuo;
GO

-- 6. Lentelė Mob_telefonas
IF OBJECT_ID('FK_Abonentas_Mob_telefonas', 'F') IS NOT NULL
    ALTER TABLE Abonentas DROP CONSTRAINT FK_Abonentas_Mob_telefonas;
IF COL_LENGTH('Abonentas', 'mobTelID') IS NOT NULL
    EXEC('UPDATE Abonentas SET mobTelID = NULL');
DROP TABLE IF EXISTS Mob_telefonas;

CREATE TABLE Mob_telefonas (
    mobTelID    INT IDENTITY(1, 1) PRIMARY KEY,  -- faile ID tuščias, todėl generuojamas automatiškai
    gamintojas  VARCHAR(15),
    modelis     VARCHAR(30),
    kaina       FLOAT,
    [kaina/men] FLOAT
);

SELECT * FROM Mob_telefonas;
GO

-- 7. Abonentas: atributas "mobTelID"
IF OBJECT_ID('FK_Abonentas_Mob_telefonas', 'F') IS NOT NULL
    ALTER TABLE Abonentas DROP CONSTRAINT FK_Abonentas_Mob_telefonas;
IF COL_LENGTH('Abonentas', 'mobTelID') IS NOT NULL
    ALTER TABLE Abonentas DROP COLUMN mobTelID;

ALTER TABLE Abonentas
ADD mobTelID INT NULL;

EXEC('SELECT TOP 10 abonentoID, numeris, mobTelID FROM Abonentas');   -- EXEC, nes stulpelis sukurtas tame pačiame bloke
GO

-- 8. Išorinis raktas Abonentas.mobTelID -> Mob_telefonas.mobTelID
IF OBJECT_ID('FK_Abonentas_Mob_telefonas', 'F') IS NOT NULL
    ALTER TABLE Abonentas DROP CONSTRAINT FK_Abonentas_Mob_telefonas;

ALTER TABLE Abonentas
ADD CONSTRAINT FK_Abonentas_Mob_telefonas
    FOREIGN KEY (mobTelID) REFERENCES Mob_telefonas (mobTelID);

SELECT name AS isorinis_raktas FROM sys.foreign_keys WHERE name = 'FK_Abonentas_Mob_telefonas';
GO

-- 9. Mob_telefonas pildymas iš .txt failo su BULK INSERT
IF EXISTS (SELECT 1 FROM Mob_telefonas)
BEGIN
    IF COL_LENGTH('Abonentas', 'mobTelID') IS NOT NULL
        EXEC('UPDATE Abonentas SET mobTelID = NULL');                -- atlaisvinami ankstesni priskyrimai
    DELETE FROM Mob_telefonas;                                       -- pašalinami ankstesni įrašai
    DBCC CHECKIDENT ('Mob_telefonas', RESEED, 0) WITH NO_INFOMSGS;   -- mobTelID vėl pradeda nuo 1
END;

BULK INSERT Mob_telefonas
FROM 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\mobilieji-telefonai.txt'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0d',   -- faile eilutės baigiasi tik CR simboliu
    FIRSTROW        = 2,
    CODEPAGE        = '65001'
);

SELECT * FROM Mob_telefonas;
GO

-- 10. Telefonas atsitiktinai priskiriamas abonentams, kurių sutarties pabaiga neapibrėžta
UPDATE a
SET a.mobTelID = t.mobTelID
FROM Abonentas a
CROSS APPLY (
    SELECT TOP 1 mobTelID
    FROM Mob_telefonas
    WHERE a.abonentoID IS NOT NULL
    ORDER BY NEWID()
) t
WHERE a.sutartiesPabaiga IS NULL;

SELECT TOP 10 a.abonentoID, a.sutartiesPabaiga, m.gamintojas, m.modelis
FROM Abonentas a
JOIN Mob_telefonas m ON m.mobTelID = a.mobTelID;
GO
