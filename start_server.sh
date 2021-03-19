# This fille calls srcds_run, also steamacc_autoexe.cfg adds the steam server token via sv_setsteamaccount XXXXXXXXXXXXXXXXXXXXXXXXX
screen -d -m -S "TF2_FF2_SERVER_TERMINAL" ./srcds_run -game tf +map arena_lumberyard -nohltv +exec steamacc_autoexec.cfg +maxplayers 32 -port 27015 +ip 0.0.0.0
