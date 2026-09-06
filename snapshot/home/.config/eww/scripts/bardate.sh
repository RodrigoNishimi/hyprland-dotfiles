#!/usr/bin/env bash
# Data da ilha do relógio: "ter, 01 set".
# O locale do sistema é en_US, então dia e mês são traduzidos aqui.
dias=(dom seg ter qua qui sex sáb)
meses=(jan fev mar abr mai jun jul ago set out nov dez)
printf '%s, %s %s\n' "${dias[$(date +%w)]}" "$(date +%d)" "${meses[10#$(date +%m) - 1]}"
