# Chrono Reader

Proyecto iOS (SwiftUI) para lectura de EPUB, cómics y audiolibros.

## Estructura del repositorio

```
App/
  ChronoReaderApp.swift          # Entry point de la app
Info.plist                       # Configuración principal de iOS
Docs/
  Audio/                         # Guías de reproducción en segundo plano
  Readers/                       # Documentación de lectores
Models/                          # Modelos de dominio
  Collections/                   # Modelos de colecciones
  EPUB/                          # Modelos específicos de EPUB
  Library/                       # Libros y metadata base
  Reading/                       # Progreso y marcadores
Resources/                       # Assets y recursos
Preview Content/                 # Assets usados en previews
Services/                        # Servicios de negocio
  Archive/                       # Lectura de archivos comprimidos
  Audio/                         # Audio y background playback
  Books/                         # Servicios de búsqueda/catalogación
  EPUB/                          # Parseo y paginación EPUB
  Metadata/                      # Títulos personalizados y metadata
  Reading/                       # Progreso de lectura
Utils/                           # Utilidades compartidas
  Cache/                         # Caché de imágenes
Views/
  AppShell/
    Views/                        # Navegación principal (tabs, shell)
  Features/
    Audio/
      Views/                      # UI de audiolibros
    Collections/
      Views/                      # Pantallas de colecciones
      Components/                 # Componentes de colecciones
      ViewModels/                 # Lógica de colecciones
    Comic/
      Views/                      # UI del lector de cómics
    EPUB/
      Views/                      # UI del lector EPUB
      ViewModels/                 # Lógica del lector EPUB
    Home/
      Views/                      # UI principal y settings
      Components/                 # Componentes de home
  Shared/                        # Componentes reutilizables
```

## Notas

- Si abrís el proyecto en Xcode, asegurate de re‑vincular los archivos movidos en el target.
- La reproducción en segundo plano requiere habilitar `Background Modes` (ver `Docs/Audio/BackgroundPlaybackConfig.md`).
