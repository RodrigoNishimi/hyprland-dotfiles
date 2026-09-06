#!/usr/bin/env bash
# Data por extenso do popup do calendário, em português.
# O locale do sistema é en_US, então os nomes são traduzidos aqui.
dias=(domingo segunda-feira terça-feira quarta-feira quinta-feira sexta-feira sábado)
meses=(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)
printf '%s, %s de %s\n' "${dias[$(date +%w)]}" "$(date +%-d)" "${meses[10#$(date +%m) - 1]}"
