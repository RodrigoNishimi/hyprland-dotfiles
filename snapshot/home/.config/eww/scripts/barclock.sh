#!/usr/bin/env bash
# Relógio da barra: dia da semana abreviado, dia e mês (sem ano).
# O locale do sistema é en_US, então o dia da semana é traduzido aqui.
dias=(dom seg ter qua qui sex sáb)
printf '%s, %s\n' "${dias[$(date +%w)]}" "$(date +'%d/%m  %H:%M')"
