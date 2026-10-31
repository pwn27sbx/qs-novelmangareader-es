# Canario de fuentes (Sentry cron + Discord)

Comprueba cada día que las fuentes en español sigan cumpliendo su contrato (búsqueda, detalle,
capítulos, lector, imagen). No es un test de la app: es un test de los sitios de los que depende.

## Instalación (una vez)

```bash
mkdir -p ~/.config/systemd/user
cp extras/systemd/qs-nmr-canary.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now qs-nmr-canary.timer
```

El archivo de secretos va aparte, en `~/.config/qs-nmr/canary.env` (modo `600`, fuera del repo):

```
QS_DISCORD_WEBHOOK=https://discord.com/api/webhooks/…
QS_SENTRY_DSN=https://<key>@o<org>.ingest.<region>.sentry.io/<project>
QS_SENTRY_CHECKIN=https://o<org>.ingest.<region>.sentry.io/api/<project>/cron/<slug>/<key>/
```

Cualquier valor vacío apaga ese canal. El DSN solo lo usa la etapa S5 del plan (SDK en el backend);
el canario usa el check-in y el webhook.

## Uso manual

```bash
scripts/source_canary.py                    # todo, con check-in y aviso
scripts/source_canary.py --source zonatmo_org
scripts/source_canary.py --no-report        # sin tocar Sentry ni Discord
scripts/source_canary.py --fail zonatmo     # fuerza un fallo para probar el aviso
```

`--fail` no consulta nada: agrega una línea `FAIL <fuente>: forced failure` y sale con código 1,
que es lo que dispara el mensaje de Discord. Útil para probar el canal sin esperar a que un sitio
se rompa.

## Qué significa cada salida

```
ok   zonatmo_org: search=3 chapters=204 pages=12 image=ok
FAIL mangadex: image: not an image (html or placeholder)
```

- `search=N` resultados para la consulta fija de esa fuente.
- `chapters=N` capítulos en español del primer resultado que tenga alguno.
- `pages=N` imágenes del primer capítulo.
- `image` valida bytes mágicos (webp/png/jpeg/gif/avif) y tamaño mínimo: un `200` con HTML o un
  placeholder no cuenta.

## Notas

- El timer corre a las **09:15 locales**, 30 min después de la hora que espera el monitor de Sentry,
  dentro del margen de 180 min.
- `Persistent=true` recupera una corrida perdida al encender la máquina. Si estuvo apagada más de
  3 h después de las 09:00, Sentry puede mandar un aviso de "missed check-in": es un aviso de que
  nadie verificó, no de que una fuente se rompió.
- La ruta del repo está en el `ExecStart`: si el checkout se mueve, se ajusta esa línea.
