#!/bin/sh
# GIT_ASKPASS helper: печатает логин/пароль из переменных окружения.
# Секретов в файле НЕТ.
case "$1" in
  Username*) printf '%s\n' "${GH_USER:-phixenium-vsue}" ;;
  Password*) printf '%s\n' "${GH_TOKEN}" ;;
  *) printf '%s\n' "" ;;
esac
