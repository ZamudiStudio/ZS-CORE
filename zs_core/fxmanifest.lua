fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'zs_core'
author 'Zamudi Studio'
description 'Zamudi Studio Core: Konten, Charaktere, Geld, Jobs, Callbacks, UID'
version '1.0.0'

dependencies { 'oxmysql' }

shared_scripts { 'config.lua' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/schema.lua',
    'server/players.lua',
    'server/api.lua',
    'server/uid.lua',
    'server/goldstaub.lua',
    'server/banner.lua',
}

client_scripts { 'client/main.lua' }
