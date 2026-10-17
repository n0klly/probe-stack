#!/usr/bin/env bash
# Стек с нуля одной командой: bash deploy.sh <версия>
# Всё, что в угловых скобках, заменить значениями своего варианта.
# Строки с комментарием «ДОПИСАТЬ» заменить своими командами.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=${1:?укажите версию: bash deploy.sh 5.0}
PREFIX=makeev-10
PORT=8030
REGISTRY=localhost:6010
IMAGE=$REGISTRY/$PREFIX/probe:$VERSION

# 1. Режим Swarm: включить, если он выключен.
#    Состояние: docker info --format '{{.Swarm.LocalNodeState}}' — active или inactive.
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" != "active" ]; then
  docker swarm init
fi

# 2. Свой реестр: создать контейнер registry:2, если его ещё нет.
#    Есть ли он: docker ps -a --format '{{.Names}}' | grep -qx "$PREFIX-registry"
if ! docker ps -a --format '{{.Names}}' | grep -qx "$PREFIX-registry"; then
  docker run -d --name "$PREFIX-registry" -p 6010:5000 --restart unless-stopped -v "$PREFIX-registry":/var/lib/registry registry:2
fi
until curl -sf "$REGISTRY/v2/" > /dev/null; do sleep 1; done

# 3. Образ: собрать с версией $VERSION и отправить в реестр.
docker build --build-arg VERSION="$VERSION" -t "$IMAGE" .
docker push "$IMAGE"

# 4. Стек: развернуть stack.yaml, передав в него VERSION.
VERSION="$VERSION" docker stack deploy --detach=false -c stack.yaml "$PREFIX"

# 5. Дождаться ответа приложения, не дольше 90 секунд.
SECONDS=0
until curl -sf -m 2 "127.0.0.1:$PORT/notes" > /dev/null; do
  if [ $SECONDS -ge 90 ]; then echo "приложение не ответило за 90 секунд" >&2; exit 1; fi
  sleep 2
done
curl -s "127.0.0.1:$PORT/notes"; echo
