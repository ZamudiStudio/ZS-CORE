fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'zs_character'
author 'Zamudi Studio'
description 'Zamudi Studio Charaktere: Auswahl, Erstellung, Aussehen, Spawn'
version '1.0.0'

dependencies { 'zs_core' }

shared_scripts {
    'config.lua',
    'data/catalog.lua',
}

server_scripts { 'server/main.lua' }

client_scripts {
    'client/appearance.lua',
    'client/main.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}
