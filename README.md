# potencia-sfp-prometheus

Exporter de Prometheus que recolecta métricas de potencia óptica (SFP) de switches Dell EMC via SSH.

Expone métricas de **rx-power**, **tx-power** y **tx-bias-current** por interfaz y sub-puerto en formato Prometheus en `/metrics`.

## Estructura del repositorio

```
├── app/                           # Código fuente y build de la imagen Docker
│   ├── Dockerfile
│   ├── build-image.sh
│   ├── requirements.txt
│   ├── potencia-prometehus-cm.py
│   └── element.ssh                  # Mapeo IP -> nombre de switch
├── deploy/                        # Helm chart multi-sitio + manifiestos ArgoCD
│   ├── Chart.yaml
│   ├── values.yaml                  # Valores base (site.name vacío)
│   ├── values-barracas.yaml         # Switches de Barracas
│   ├── values-cuyo.yaml             # Switches de Cuyo
│   ├── values-republica.yaml        # Switches de República
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── serviceaccount.yaml
│   └── argocd/
│       └── application-set.yaml     # ApplicationSet → 1 App por sitio
└── scripts/
    └── build.sh                     # Script de build del pipeline CI
```

## Arquitectura de despliegue

Cada sitio monitoreado tiene su propio pod independiente con sus switches. El chart es genérico: se instancia una vez por sitio con un archivo de valores específico.

| Sitio | Application | Deployment | Service | Switches |
|-------|-------------|------------|---------|----------|
| barracas | `potencia-sfp-barracas` | `potencia-barracas` | `potencia-barracas` | 16 |
| cuyo | `potencia-sfp-cuyo` | `potencia-cuyo` | `potencia-cuyo` | 10 |
| republica | `potencia-sfp-republica` | `potencia-republica` | `potencia-republica` | 7 |

## Flujo CI/CD

```
git push a GitLab (cambios en app/)
       │
       ▼
┌─────────────────────┐
│  Pipeline CI         │
│  build + push        │
│  imagen a Harbor     │
│  (<sha> y latest)    │
└────────┬────────────┘
         │
         ▼  (manual: actualizar tag en values-<sitio>.yaml)
         │
         ▼
┌─────────────────────┐
│  ArgoCD detecta     │
│  cambio en git      │
│  → sync automático  │
│  → rollout nueva     │
│     versión          │
└─────────────────────┘
```

El pipeline solo se dispara cuando cambian archivos en `app/`, `.gitlab-ci.yml` o `scripts/`. Los cambios en `deploy/` **no** disparan build.

## Despliegue con Helm

```sh
cd deploy
helm upgrade --install potencia-barracas . \
  --namespace grafana-operaciones \
  --create-namespace \
  -f values-barracas.yaml
```

Para otro sitio, cambiar el values file:

```sh
helm upgrade --install potencia-cuyo . \
  --namespace grafana-operaciones \
  --create-namespace \
  -f values-cuyo.yaml
```

### Credenciales SSH

Cada sitio necesita un Secret con las credenciales SSH de sus switches. El nombre sigue el patrón `potencia-<sitio>-ssh`:

```sh
kubectl create secret generic potencia-barracas-ssh \
  --namespace grafana-operaciones \
  --from-literal=username=<usuario> \
  --from-literal=password=<password>
```

Se puede overridear con `existingSecret` en values.

## Despliegue con ArgoCD

El archivo `deploy/argocd/application-set.yaml` define un ApplicationSet que crea una Application de ArgoCD por cada sitio.

```sh
kubectl apply -f deploy/argocd/application-set.yaml
```

Esto crea las aplicaciones en el namespace `argocd`:

| Application | Values file |
|---|---|
| `potencia-sfp-barracas` | `values-barracas.yaml` |
| `poltencia-sfp-cuyo` | `values-cuyo.yaml` |
| `potencia-sfp-republica` | `values-republica.yaml` |

Políticas de sync:
- **Auto-prune**: elimina recursos que ya no están en el chart
- **Self-heal**: revierte cambios manuales al estado del repositorio
- **CreateNamespace**: crea `grafana-operaciones` si no existe
- **Retry**: hasta 5 reintentos con backoff exponencial

### Agregar un nuevo sitio

1. Crear `deploy/values-<sitio>.yaml` con los switches del sitio
2. Agregar `- site: <sitio>` al `list` generator en `deploy/argocd/application-set.yaml`
3. Commitear y pushear a GitLab
4. ArgoDC sincroniza automáticamente y crea el nuevo deployment

## Build de la imagen

### Manual (local)

```sh
cd app
./build-image.sh
```

### Automático (GitLab CI)

Al pushear cambios en `app/` a `main` en GitLab, el pipeline:

1. Kaniko buildea la imagen usando la base de Harbor
2. Pushea a Harbor: `power-metrics/potencia-sfp-prometehus-cm:<sha>` y `latest`

### Disparar el pipeline manualmente

1. Ir a **Build > Pipelines** en el proyecto de GitLab
2. Click en **Run pipeline**
3. Seleccionar `main` y click en **Run pipeline**

## CI/CD Pipeline (GitLab)

### Infraestructura

| Componente | URL |
|-----------|-----|
| GitLab | `https://whitecicd-tt.cuyows.tcloud.ar` |
| Harbor (registry) | `https://whiteregistry.cuyows.tcloud.ar` |

### Proyectos en Harbor

| Proyecto | Uso |
|----------|-----|
| `whitecicd-pipeline` | Imágenes helper del CI (kaniko, base con pip) |
| `power-metrics` | Imagen final de la aplicación |

### Imágenes disponibles

| Imagen | Descripción |
|--------|-------------|
| `whitecicd-pipeline/kaniko-git:debug` | Kaniko + git, usada por el runner para buildear |
| `whitecicd-pipeline/python-sfp-base:3.11` | Python 3.11 slim con dependencias pre-instaladas |
| `power-metrics/potencia-sfp-prometehus-cm` | Imagen final de la app (output del pipeline) |

### Cómo funciona el pipeline

1. El runner de GitLab (Kubernetes executor) levanta un pod con la imagen `kaniko-git`
2. Clona el repo usando un **deploy token** (`GIT_DEPLOY_TOKEN`)
3. Kaniko buildea la imagen usando la base de Harbor
4. Pushea la imagen final a Harbor con tags: `latest` + SHA del commit

### Variables de CI/CD necesarias

Configuradas en **Settings > CI/CD > Variables** del proyecto:

| Variable | Valor | Masked |
|----------|-------|--------|
| `GIT_DEPLOY_TOKEN` | Token de deploy con scope `read_repository` | ✅ |
| `HARBOR_USER` | Usuario de Harbor | ✅ |
| `HARBOR_PASSWORD` | Password de Harbor | ✅ |

### Troubleshooting

#### El runner no puede clonar el repo
- Verificar que `GIT_DEPLOY_TOKEN` esté configurada y no marcada como **Protected**
- Verificar que el token no haya expirado

#### Error de certificado TLS con Harbor
- El registry usa certificado self-signed. Kaniko lo saltea con `--skip-tls-verify-registry`

#### pip install falla por red
- El runner no tiene acceso a PyPI. Las dependencias se pre-instalan en la imagen base `python-sfp-base` que se buildéo localmente y subió a Harbor
- Si cambian las dependencias, rebuildear la base localmente:
  ```sh
  docker build -t whiteregistry.cuyows.tcloud.ar/whitecicd-pipeline/python-sfp-base:3.11 -f app/Dockerfile.base app/
  docker push whiteregistry.cuyows.tcloud.ar/whitecicd-pipeline/python-sfp-base:3.11
  ```
