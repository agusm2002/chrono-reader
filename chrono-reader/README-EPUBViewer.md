# Lector de EPUB para Chrono Reader

## Características principales

- **Visualización de libros EPUB**: Lee archivos EPUB con soporte para texto e imágenes.
- **Navegación intuitiva**: Pasa páginas con gestos de deslizamiento horizontal o vertical.
- **Tabla de contenidos**: Accede rápidamente a los capítulos del libro.
- **Personalización de lectura**: Ajusta tamaño de texto, fuente, espaciado y tema.
- **Temas de lectura**: Modo claro, oscuro y sepia para diferentes ambientes.
- **Marcadores**: Guarda automáticamente el progreso de lectura.
- **Interfaz moderna**: Diseño limpio y minimalista orientado a la experiencia de lectura.

## Cómo usar el lector

1. **Abrir un libro**: Toca cualquier libro EPUB en la vista principal para abrirlo.
2. **Navegación**:
   - Desliza horizontalmente para pasar páginas en modo horizontal.
   - Desliza verticalmente en modo de desplazamiento vertical.
   - Toca en el centro de la pantalla para mostrar/ocultar los controles.
   - Usa las flechas para navegar entre capítulos.

3. **Tabla de contenidos**:
   - Toca el icono de lista en la parte superior derecha para acceder a la tabla de contenidos.
   - Selecciona un capítulo para navegar directamente a él.

4. **Personalización**:
   - Toca el icono de engranaje para abrir la configuración.
   - Ajusta tamaño de texto, altura de línea, fuente, dirección de desplazamiento y tema.

## Estructura técnica

El lector de EPUB está compuesto por varios componentes:

### 1. Modelos de datos

- `EPUBBook`: Clase principal que representa un libro EPUB.
- `EPUBSpine`: Representa la secuencia ordenada de capítulos.
- `EPUBResource`: Recursos del libro (HTML, CSS, imágenes).
- `EPUBTocReference`: Items de la tabla de contenidos.

### 2. Servicio de parseo

- `EPUBService`: Encargado de extraer y procesar archivos EPUB.
- Descomprime el archivo, lee container.xml, localiza el archivo OPF.
- Extrae metadatos, recursos y la espina del libro.
- Organiza los capítulos en el orden correcto.

### 3. Vistas

- `EPUBViewerView`: Vista principal del lector.
- `EPUBPageView`: Maneja la paginación horizontal o vertical.
- `EPUBPageContentView`: Renderiza el contenido HTML de cada página.
- `EPUBTableOfContentsView`: Muestra la tabla de contenidos.
- `EPUBSettingsView`: Controles de personalización.

### 4. ViewModel

- `EPUBViewerViewModel`: Contiene la lógica del lector y mantiene el estado.
- Maneja navegación, progreso de lectura y personalización.
- Carga y procesa el contenido HTML.

## Dependencias

- `XMLCoder`: Para parsear archivos XML del EPUB.
- `ZIPFoundation`: Para descomprimir archivos EPUB.
- `WebKit`: Para renderizar el contenido HTML.

## Mejoras futuras

- Soporte para anotaciones y subrayado.
- Búsqueda en el texto.
- Sincronización entre dispositivos.
- Soporte para EPUB3 con contenido multimedia.
- Más opciones de personalización (márgenes, orientación, etc.). 