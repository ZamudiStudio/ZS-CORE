-- Datenbank-Schema von zs_core. Wird beim Start angelegt, spaetere Spalten kommen per ALTER dazu.

ZS = ZS or {}

local readyPromise = promise.new()
ZS.dbReady = false

function ZS.WaitForDatabase()
    if ZS.dbReady then return end
    Citizen.Await(readyPromise)
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS zs_accounts (
            identifier VARCHAR(80) NOT NULL,
            display_name VARCHAR(100) NOT NULL DEFAULT '',
            `group` VARCHAR(40) NOT NULL DEFAULT 'user',
            max_characters TINYINT UNSIGNED NOT NULL DEFAULT 5,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (identifier)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS zs_characters (
            id INT NOT NULL AUTO_INCREMENT,
            identifier VARCHAR(80) NOT NULL,
            firstname VARCHAR(50) NOT NULL,
            lastname VARCHAR(50) NOT NULL,
            nickname VARCHAR(50) NOT NULL DEFAULT '',
            age TINYINT UNSIGNED NOT NULL DEFAULT 25,
            gender VARCHAR(10) NOT NULL DEFAULT 'male',
            description TEXT NULL,
            job VARCHAR(50) NOT NULL DEFAULT 'unemployed',
            job_grade INT NOT NULL DEFAULT 0,
            job_label VARCHAR(80) NOT NULL DEFAULT '',
            coords LONGTEXT NULL,
            vitals LONGTEXT NULL,
            is_dead TINYINT(1) NOT NULL DEFAULT 0,
            appearance LONGTEXT NULL,
            clothing LONGTEXT NULL,
            meta LONGTEXT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_played TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (id),
            KEY idx_identifier (identifier)
        )
    ]])

    -- Kontostaende pro Charakter und Waehrung (Waehrungen stehen in Config.Currencies)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS zs_character_money (
            char_id INT NOT NULL,
            currency VARCHAR(30) NOT NULL,
            amount DOUBLE NOT NULL DEFAULT 0,
            PRIMARY KEY (char_id, currency)
        )
    ]])

    ZS.dbReady = true
    readyPromise:resolve(true)
end)
