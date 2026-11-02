fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'ws-squad'
author 'WS Scripts'
description 'Wild West squad system for RSG Framework - created by WS Scripts'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/locale.lua',
    'locales/en.lua',
    'locales/pt.lua',
    'locales/ru.lua',
}

client_script 'client/main.lua'
server_scripts {
    'server/webhook.lua',
    'server/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js',
    'nui/logo.png',
}

dependencies {
    'rsg-core',
    'ox_lib',
}
