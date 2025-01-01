USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'DB_idz')
BEGIN
    ALTER DATABASE DB_idz SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DB_idz;
END
GO

IF DB_ID('DB_idz') IS NULL
BEGIN
    CREATE DATABASE DB_idz;
END
GO

USE DB_idz;
GO

IF OBJECT_ID('Constellations', 'U') IS NOT NULL
   DROP TABLE Constellations;
GO
-- Таблиця Сузір'я
CREATE TABLE Constellations (
    constellation_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    abbreviation VARCHAR(3) NOT NULL
);


IF OBJECT_ID('Stars', 'U') IS NOT NULL
   DROP TABLE Stars;
GO
-- Таблиця Зірки
CREATE TABLE Stars (
    star_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    apparent_magnitude DECIMAL(3, 2) NOT NULL,
    distance_from_earth DECIMAL(6, 2) NOT NULL,
    right_ascension TIME NOT NULL,
    declination DECIMAL(5, 2) NOT NULL,
    constellation_id INT NOT NULL,
    FOREIGN KEY (constellation_id) REFERENCES Constellations(constellation_id)
);

IF OBJECT_ID('Locations', 'U') IS NOT NULL
   DROP TABLE Locations;
GO
-- Таблиця Локації
CREATE TABLE Locations (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    latitude DECIMAL(6, 2) NOT NULL,
    longitude DECIMAL(6, 2) NOT NULL,
    city VARCHAR(50) NOT NULL
);

IF OBJECT_ID('Visibility', 'U') IS NOT NULL
   DROP TABLE Visibility;
GO
-- Таблиця Видимість
CREATE TABLE Visibility (
    visibility_id INT IDENTITY(1,1) PRIMARY KEY,
    star_id INT NOT NULL,
    location_id INT NOT NULL,
    visible_start_time DATETIME NOT NULL,
    visible_end_time DATETIME NOT NULL,
    FOREIGN KEY (star_id) REFERENCES Stars(star_id),
    FOREIGN KEY (location_id) REFERENCES Locations(location_id)
);

IF OBJECT_ID('Star_Classifications', 'U') IS NOT NULL
   DROP TABLE Star_Classifications;
GO
-- Таблиця Класифікація Зірок
CREATE TABLE Star_Classifications (
    classification_id INT IDENTITY(1,1) PRIMARY KEY,
    star_id INT NOT NULL,
    spectral_type VARCHAR(10) NOT NULL,
    luminosity_class VARCHAR(10) NOT NULL,
    FOREIGN KEY (star_id) REFERENCES Stars(star_id)
);

IF OBJECT_ID('Observers', 'U') IS NOT NULL
   DROP TABLE Observers;
GO
-- Таблиця Спостерігачі
CREATE TABLE Observers (
    observer_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    location_id INT NOT NULL,
    FOREIGN KEY (location_id) REFERENCES Locations(location_id)
);


INSERT INTO Constellations (name, abbreviation) VALUES
('Orion', 'ORI'),
('Canis Major', 'CMA'),
('Ursa Major', 'UMA'),
('Lyra', 'LYR'),
('Cygnus', 'CYG'),
('Cassiopeia', 'CAS'),
('Scorpius', 'SCO');
GO

INSERT INTO Stars (name, apparent_magnitude, distance_from_earth, right_ascension, declination, constellation_id) VALUES
('Betelgeuse', 0.42, 548.7, '05:55:10', 7.24, 1),
('Rigel', 0.13, 863.0, '05:14:32', -8.2, 1),
('Sirius', -1.46, 8.6, '06:45:08', -16.72, 2),
('Dubhe', 1.79, 123.2, '11:03:43', 61.75, 3),
('Vega', 0.03, 25.0, '18:36:56', 38.78, 4),
('Deneb', 1.25, 2615.0, '20:41:25', 45.28, 5),
('Shedir', 2.24, 229.0, '00:40:30', 56.54, 6),
('Antares', 0.96, 550.0, '16:29:24', -26.43, 7);
GO

INSERT INTO Locations (latitude, longitude, city) VALUES
(34.05, -118.25, 'Los Angeles'),
(51.51, -0.13, 'London'),
(35.68, 139.76, 'Tokyo'),
(-33.87, 151.21, 'Sydney'),
(48.85, 2.35, 'Paris');
GO

INSERT INTO Visibility (star_id, location_id, visible_start_time, visible_end_time) VALUES
(1, 1, '2024-10-01 20:00:00', '2024-10-01 22:00:00'),
(2, 2, '2024-10-02 19:00:00', '2024-10-02 23:00:00'),
(3, 3, '2024-10-03 18:00:00', '2024-10-03 21:30:00'),
(4, 4, '2024-10-04 21:00:00', '2024-10-04 23:30:00'),
(5, 5, '2024-10-05 20:00:00', '2024-10-05 22:15:00'),
(6, 1, '2024-10-06 19:00:00', '2024-10-06 21:45:00');
GO

INSERT INTO Star_Classifications (star_id, spectral_type, luminosity_class) VALUES
(1, 'M2', 'I'),
(2, 'B8', 'I'),
(3, 'A1', 'V'),
(4, 'K0', 'III'),
(5, 'A0', 'V'),
(6, 'A2', 'I'),
(7, 'K3', 'II'),
(8, 'M1', 'I');
GO

INSERT INTO Observers (name, location_id) VALUES
('Alice Johnson', 1),
('Bob Smith', 2),
('Carol Lee', 3),
('David Brown', 4),
('Eva Green', 5);
GO

--Заборона додавання зірок із видимою зоряною величиною, більшою за 6.0 (поріг видимості зірок неозброєним оком)
CREATE TRIGGER prevent_dim_star
ON Stars
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM inserted
        WHERE apparent_magnitude > 6.0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR ('Зірка має бути видимою (зоряна величина <= 6.0).', 16, 1);
    END
END;
GO

GO
--Оновлює видимість, якщо змінюється локація спостерігача.
CREATE TRIGGER update_visibility_on_location_change
ON Observers
AFTER UPDATE
AS
BEGIN
    UPDATE Visibility
    SET location_id = (SELECT location_id FROM inserted)
    WHERE location_id = (SELECT location_id FROM deleted);
END;
GO

--Забезпечує збереження цілісності даних, видаляючи записи про видимість зірок, якщо видаляється зірка
CREATE TRIGGER cascade_delete_visibility
ON Stars
AFTER DELETE
AS
BEGIN
    DELETE FROM Visibility
    WHERE star_id IN (SELECT star_id FROM deleted);
END;
GO

-- Спроба додати зірку з величиною зоряної величини > 6.0
--INSERT INTO Stars (name, apparent_magnitude, distance_from_earth, right_ascension, declination, constellation_id) 
--VALUES ('Dim Star', 7.2, 1000.0, '00:00:00', 0.0, 1);
--Оновлення локації спостерігача
--UPDATE Observers
--ET location_id = 3
--WHERE observer_id = 1;
--Видалення зірки з таблиці
--DELETE FROM Stars
--WHERE star_id = 1;


--Які зірки видимі в місті "Los Angeles" у  "2024-10-01 21:00:00" час.
SELECT s.name AS star_name, v.visible_start_time, v.visible_end_time
FROM Visibility v
JOIN Stars s ON v.star_id = s.star_id
JOIN Locations l ON v.location_id = l.location_id
WHERE l.city = 'Los Angeles' 
AND '2024-10-01 21:00:00' BETWEEN v.visible_start_time AND v.visible_end_time;

--Кількість зірок, видимих з кожного міста
SELECT l.city, COUNT(DISTINCT v.star_id) AS visible_stars_count
FROM Locations l
JOIN Visibility v ON l.location_id = v.location_id
GROUP BY l.city
ORDER BY visible_stars_count DESC;

--Пошук зірок із певним спектральним класом у заданому сузір'ї
SELECT s.name AS star_name, sc.spectral_type, sc.luminosity_class, c.name AS constellation_name
FROM Stars s
JOIN Star_Classifications sc ON s.star_id = sc.star_id
JOIN Constellations c ON s.constellation_id = c.constellation_id
WHERE c.name = 'Orion' AND sc.spectral_type LIKE 'M%';

--Локації, де зірка "Betelgeuse" видима у певний час
SELECT l.city, v.visible_start_time, v.visible_end_time
FROM Visibility v
JOIN Locations l ON v.location_id = l.location_id
JOIN Stars s ON v.star_id = s.star_id
WHERE s.name = 'Betelgeuse' AND '2024-10-01 21:00:00' BETWEEN v.visible_start_time AND v.visible_end_time;

--Зірки з найбільшою відстанню у кожному сузір'ї
WITH MaxDistance AS (
    SELECT 
        c.name AS constellation_name, 
        s.name AS star_name, 
        s.distance_from_earth,
        ROW_NUMBER() OVER (PARTITION BY c.name ORDER BY s.distance_from_earth DESC) AS rn
    FROM Stars s
    JOIN Constellations c ON s.constellation_id = c.constellation_id
)
SELECT constellation_name, star_name, distance_from_earth AS max_distance
FROM MaxDistance
WHERE rn = 1;

-- Найяскравіші зірки для кожного сузір'я
IF OBJECT_ID('BrightestStarsByConstellation', 'V') IS NOT NULL
    DROP VIEW BrightestStarsByConstellation;
GO
CREATE VIEW BrightestStarsByConstellation AS
SELECT 
    c.name AS constellation_name, 
    s.name AS star_name, 
    MIN(s.apparent_magnitude) AS brightest_magnitude
FROM Stars s
JOIN Constellations c ON s.constellation_id = c.constellation_id
GROUP BY c.name, s.name;
GO
SELECT * FROM BrightestStarsByConstellation;
GO

-- Список спостерігачів із їхніми локаціями та найяскравішими зірками
IF OBJECT_ID('ObserverVisibleBrightestStars', 'V') IS NOT NULL
    DROP VIEW ObserverVisibleBrightestStars;
GO
CREATE VIEW ObserverVisibleBrightestStars AS
SELECT 
    o.name AS observer_name, 
    l.city AS location_city, 
    s.name AS star_name, 
    MIN(s.apparent_magnitude) AS brightest_magnitude
FROM Observers o
JOIN Locations l ON o.location_id = l.location_id
JOIN Visibility v ON l.location_id = v.location_id
JOIN Stars s ON v.star_id = s.star_id
GROUP BY o.name, l.city, s.name;
GO
SELECT * FROM ObserverVisibleBrightestStars;
GO


-- First Procedure: GetVisibleStarsByLocationAndTime
CREATE OR ALTER PROCEDURE GetVisibleStarsByLocationAndTime
    @City NVARCHAR(50), 
    @StartTime DATETIME, 
    @EndTime DATETIME,
    @SpectralType NVARCHAR(10) = NULL -- Optional filter by spectral type
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.name AS StarName, 
        c.name AS ConstellationName, 
        sc.spectral_type AS SpectralType,
        v.visible_start_time AS VisibilityStartTime,
        v.visible_end_time AS VisibilityEndTime
    FROM Stars s
    JOIN Visibility v ON s.star_id = v.star_id
    JOIN Locations l ON v.location_id = l.location_id
    JOIN Constellations c ON s.constellation_id = c.constellation_id
    LEFT JOIN Star_Classifications sc ON s.star_id = sc.star_id
    WHERE l.city = @City
        AND v.visible_start_time <= @EndTime 
        AND v.visible_end_time >= @StartTime
        AND (@SpectralType IS NULL OR sc.spectral_type = @SpectralType)
    ORDER BY v.visible_start_time;
END;
GO

EXEC GetVisibleStarsByLocationAndTime 
    @City = 'Los Angeles', 
    @StartTime = '2024-10-01 19:00:00', 
    @EndTime = '2024-10-01 22:00:00',
    @SpectralType = 'M2';
GO


IF OBJECT_ID('AddStarWithClassification', 'P') IS NOT NULL
    DROP PROCEDURE AddStarWithClassification;
GO

CREATE PROCEDURE AddStarWithClassification
    @StarName NVARCHAR(50),
    @ApparentMagnitude DECIMAL(3, 2),
    @DistanceFromEarth DECIMAL(6, 2),
    @RightAscension TIME,
    @Declination DECIMAL(5, 2),
    @ConstellationName NVARCHAR(50),
    @SpectralType NVARCHAR(10),
    @LuminosityClass NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    -- Отримуємо ID сузір'я, якщо не існує, додаємо
    DECLARE @ConstellationID INT;
    IF NOT EXISTS (SELECT 1 FROM Constellations WHERE name = @ConstellationName)
    BEGIN
        INSERT INTO Constellations (name, abbreviation)
        VALUES (@ConstellationName, LEFT(@ConstellationName, 3));

        SET @ConstellationID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        SELECT @ConstellationID = constellation_id
        FROM Constellations
        WHERE name = @ConstellationName;
    END

    -- Додаємо зірку
    INSERT INTO Stars (name, apparent_magnitude, distance_from_earth, right_ascension, declination, constellation_id)
    VALUES (@StarName, @ApparentMagnitude, @DistanceFromEarth, @RightAscension, @Declination, @ConstellationID);

    DECLARE @StarID INT = SCOPE_IDENTITY();

    -- Додаємо класифікацію зірки
    INSERT INTO Star_Classifications (star_id, spectral_type, luminosity_class)
    VALUES (@StarID, @SpectralType, @LuminosityClass);

    -- Повертаємо дані про додану зірку
    SELECT 
        s.star_id,
        s.name AS StarName,
        s.apparent_magnitude AS ApparentMagnitude,
        s.distance_from_earth AS DistanceFromEarth,
        s.right_ascension AS RightAscension,
        s.declination AS Declination,
        c.name AS ConstellationName,
        sc.spectral_type AS SpectralType,
        sc.luminosity_class AS LuminosityClass
    FROM Stars s
    JOIN Constellations c ON s.constellation_id = c.constellation_id
    JOIN Star_Classifications sc ON s.star_id = sc.star_id
    WHERE s.star_id = @StarID;
END;
GO

--SELECT * 
--FROM sys.objects
--WHERE type = 'P' AND name = 'AddStarWithClassification';

EXEC AddStarWithClassification 
    @StarName = 'New Star', 
    @ApparentMagnitude = 2.5, 
    @DistanceFromEarth = 300.0, 
    @RightAscension = '02:30:00', 
    @Declination = -10.5, 
    @ConstellationName = 'Orion', 
    @SpectralType = 'G2', 
    @LuminosityClass = 'V';
GO



