# Configuración de Reproducción en Segundo Plano

Para asegurar que la reproducción de audio funcione correctamente en segundo plano, es necesario habilitar las capacidades de reproducción en segundo plano en el proyecto de Xcode.

## Pasos para habilitar la reproducción en segundo plano

1. Abre el proyecto en Xcode
2. Selecciona el target principal de la aplicación
3. Ve a la pestaña "Signing & Capabilities"
4. Haz clic en "+ Capability"
5. Busca y añade "Background Modes"
6. Marca la casilla "Audio, AirPlay, and Picture in Picture"

## Verificación

Una vez habilitada esta capacidad, el archivo Info.plist debería contener la siguiente entrada:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

## Solución de problemas comunes

Si la reproducción en segundo plano sigue sin funcionar correctamente después de habilitar las capacidades, verifica lo siguiente:

1. **Asegúrate de que la app esté firmada correctamente**: Las capacidades requieren que la app esté firmada con un perfil de aprovisionamiento válido.

2. **Verifica que el AudioManager se inicialice correctamente**: El AudioManager debe inicializarse al inicio de la aplicación.

3. **Comprueba los registros de la consola**: Busca mensajes relacionados con la sesión de audio para identificar posibles problemas.

4. **Prueba en un dispositivo físico**: El comportamiento de reproducción en segundo plano puede ser diferente en el simulador y en un dispositivo físico.

## Notas adicionales

- La reproducción en segundo plano consume más batería, por lo que es importante manejar correctamente los recursos.
- Asegúrate de que la aplicación responda adecuadamente a interrupciones como llamadas telefónicas o alarmas.
- La reproducción en segundo plano puede comportarse de manera diferente en diferentes versiones de iOS.
