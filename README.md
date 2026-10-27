# Windows Maintenance Toolkit

Script de PowerShell para automatizar tareas de mantenimiento preventivo y diagnóstico en equipos Windows, con integración opcional de Windows Update y Dell Command Update.

**Contenido**

- [Descripción](#descripción)
- [Características](#características)
- [Resultados obtenidos](#resultados-obtenidos)
- [Requisitos](#requisitos)
- [Ejecución](#ejecución)
- [Capturas de pantalla](#capturas-de-pantalla)
- [Contribuciones](#contribuciones)
- [Licencia](#licencia)

## Descripción

Windows Maintenance Toolkit reúne tareas habituales de mantenimiento en un único script: limpieza de archivos temporales, consulta del estado de almacenamiento y memoria, optimización de la unidad C y ejecución de actualizaciones cuando sus herramientas están disponibles.

Está orientado a técnicos de soporte y administradores que necesitan estandarizar el mantenimiento preventivo. La ejecución es secuencial y muestra información en la consola.

## Características

- Verificación de permisos de administrador antes de comenzar.
- Limpieza de temporales del usuario y de `C:\Windows\Temp`.
- Vaciado de la papelera de reciclaje y limpieza de la caché DNS.
- Consulta del tipo y estado de salud de los discos físicos.
- Resumen de RAM total, utilizada y disponible.
- Listado de los diez procesos con mayor consumo de memoria.
- Optimización de la unidad C mediante `Optimize-Volume`.
- Búsqueda y aplicación de actualizaciones Dell cuando encuentra `dcu-cli.exe` en las rutas previstas.
- Búsqueda e instalación de parches y otras actualizaciones mediante `PSWindowsUpdate`, separadas de las actualizaciones de versión.
- Detección de la versión actual y búsqueda de upgrades ofrecidos para Windows 11 cliente mediante Microsoft Update, sin fijar una versión de destino como 26H2.
- Resultados de instalación y resumen final del estado de Windows Update, con verificación posterior mediante `winver`.
- Consulta de temperatura, errores, desgaste y horas de uso del almacenamiento cuando el hardware y sus controladores exponen estos datos.
- Comprobación del indicador de reinicio pendiente de Windows Update.
- Opción de programar un reinicio en 120 segundos al finalizar.

## Resultados obtenidos

Según la experiencia de uso reportada en este proyecto, se han realizado pruebas en múltiples equipos Windows y observado los siguientes beneficios:

- Reducción del tiempo de intervención técnica.
- Estandarización del proceso de mantenimiento.
- Integración de múltiples tareas en una sola ejecución.
- Mayor consistencia en la aplicación del procedimiento.

El tiempo total reportado pasó, en la mayoría de los casos, de aproximadamente **2–3 horas a menos de una hora**. Es una referencia de esas intervenciones; el tiempo real depende del equipo, el almacenamiento, la conexión y las actualizaciones pendientes.

No se incluyen mediciones comparativas de rendimiento ni un protocolo de evaluación reproducible. El mensaje `MANTENIMIENTO COMPLETADO` indica que se alcanzó el final del script; algunas operaciones pueden haberse omitido o fallado, por lo que debe revisarse la salida de la consola.

### Actualización de versión: prueba confirmada

Se confirmó una actualización de **Windows 11 24H2 a 25H2** en un equipo de pruebas. La ejecución encontró la actualización de versión, mostró las etapas `Accepted`, `Downloaded` e `Installed`, indicó que hacía falta reiniciar y el responsable de la prueba confirmó **25H2 después del reinicio**.

La revisión publicada conserva la búsqueda mediante la categoría `Upgrades` y añade separación de parches, filtro para Windows 11 cliente, manejo de errores y resumen de resultados. Estas mejoras adicionales pasaron la revisión de sintaxis y siete pruebas con respuestas simuladas; la revisión completa aún requiere validación en un equipo de pruebas. El caso 24H2 → 25H2 no garantiza la disponibilidad de otras versiones o rutas de actualización.

## Requisitos

- Un equipo Windows con los cmdlets de almacenamiento utilizados por el script disponibles. Validar la compatibilidad en el entorno de destino.
- Windows PowerShell 5.1 como entorno de ejecución recomendado; la compatibilidad con PowerShell 7 no está documentada en este proyecto.
- Permisos de administrador.
- Unidad C disponible para la optimización y acceso a las rutas de temporales utilizadas.
- Conexión a Internet para buscar y descargar actualizaciones.
- Módulo `PSWindowsUpdate` para las actualizaciones de Windows. Si falta, el script intenta instalarlo desde `PSGallery` para el usuario actual y preparar el proveedor NuGet; se necesita acceso a PowerShell Gallery. Si la preparación falla, informa del error y continúa con las tareas restantes.
- Windows 11 cliente para el bloque de cambio de versión. Ese bloque se omite en Windows Server y Windows 10; esto no constituye una validación de compatibilidad del resto del script con esos sistemas.
- **Opcional:** Dell Command Update instalado en un equipo Dell compatible. El script busca su ejecutable en `C:\Program Files\Dell\CommandUpdate\dcu-cli.exe` y `C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe`. Si no lo encuentra, omite esa parte.

Los datos avanzados del almacenamiento dependen de la compatibilidad del dispositivo y de sus controladores.

## Ejecución

> **Antes de comenzar:** guarda tu trabajo y revisa el script. La ejecución elimina archivos temporales, vacía la papelera sin confirmación e intenta instalar parches y actualizaciones de versión ofrecidas para Windows 11. También puede instalar el módulo `PSWindowsUpdate` y preparar NuGet si no están disponibles. No incluye un modo de simulación ni una selección interactiva de tareas o actualizaciones. En entornos productivos, valida previamente el procedimiento y programa una ventana de mantenimiento.

1. Descarga el repositorio desde **Code → Download ZIP** y extrae su contenido, o clónalo si tienes Git instalado:

   ```powershell
   git clone https://github.com/odejft/Windows-Maintenance-Toolkit.git
   ```

2. Abre **Windows PowerShell como administrador** y sitúate en la carpeta descargada o clonada. Si la clonaste desde tu ubicación actual:

   ```powershell
   Set-Location .\Windows-Maintenance-Toolkit
   ```

3. Puedes instalar previamente el módulo desde PowerShell Gallery, revisando las confirmaciones que aparezcan. Si falta al ejecutar el script, este intentará instalarlo automáticamente:

   ```powershell
   Install-Module -Name PSWindowsUpdate -Scope CurrentUser
   ```

4. Ejecuta el script:

   ```powershell
   .\Windows-Maintenance-Toolkit.ps1
   ```

   Si Windows bloquea un archivo descargado, revisa su contenido y procedencia antes de desbloquearlo:

   ```powershell
   Unblock-File -Path .\Windows-Maintenance-Toolkit.ps1
   ```

   Si una directiva de tu organización impide la ejecución, consulta al administrador del entorno.

5. Revisa los mensajes y resultados de la consola. Al finalizar, responde `S` si deseas programar el reinicio o `N` para continuar sin reiniciar.

   Si aceptaste el reinicio, puedes cancelarlo durante la cuenta regresiva con:

   ```powershell
   shutdown /a
   ```

La llamada a Windows Update utiliza `-AcceptAll -IgnoreReboot`: acepta las actualizaciones y evita el reinicio automático de esa operación. La integración Dell se ejecuta por separado; revisa también sus resultados y requisitos de reinicio.

### Cómo se procesan las actualizaciones de Windows

1. Se detecta la versión instalada y se intenta iniciar `wuauserv` y `BITS` si no están en ejecución. No se cambia su tipo de inicio ni se modifican directivas.
2. Se consultan e instalan parches y otras actualizaciones excluyendo la categoría `Upgrades`.
3. En Windows 11 cliente se consultan por separado las actualizaciones de categoría `Upgrades` cuyo título contiene `Windows 11`. Se intenta instalar lo que Microsoft Update ofrezca al equipo; no se fuerza una versión concreta ni se garantiza instalar la siguiente o la más reciente.
4. Se muestran los resultados devueltos por el módulo y el resumen final. Un resultado `Installed` no sustituye la comprobación posterior al reinicio.
5. Después del reinicio, ejecuta `winver` y confirma la versión. Si aún faltaban parches o requisitos, puede ser necesario volver a ejecutar el script.

Si no se ofrece un upgrade, revisa reinicios pendientes, requisitos, directivas de versión objetivo, WSUS/Intune y bloqueos de compatibilidad. El script no elimina esas restricciones ni ejecuta un escaneo de fondo dando por hecho que terminó. En equipos administrados, verifica que el uso explícito de Microsoft Update corresponda a la política de tu organización.

## Capturas de pantalla

Las siguientes capturas documentan ejemplos de ejecución. La salida puede variar según el equipo y las herramientas disponibles.

![Ejemplo de ejecución del mantenimiento, captura 1](https://github.com/user-attachments/assets/7211fc25-5849-4016-8ac9-ccf925d256b8)

![Ejemplo de ejecución del mantenimiento, captura 2](https://github.com/user-attachments/assets/0bf1117c-3327-4846-b36c-8fa37972d1bf)

![Ejemplo de ejecución del mantenimiento, captura 3](https://github.com/user-attachments/assets/e147cd3c-201d-4f7d-b648-896ffda8fec6)

![Ejemplo de ejecución del mantenimiento, captura 4](https://github.com/user-attachments/assets/032d911f-36bf-426d-b25e-7f06833f4dbe)

![Ejemplo de ejecución del mantenimiento, captura 5](https://github.com/user-attachments/assets/87475fe7-addb-43f0-b76c-f46fa943b50f)

## Contribuciones

Las sugerencias, correcciones y mejoras son bienvenidas.

1. Abre un [issue](https://github.com/odejft/Windows-Maintenance-Toolkit/issues) para describir el problema o proponer una mejora.
2. Para contribuir código o documentación, crea un fork y una rama con tus cambios.
3. Valida los cambios en un equipo de pruebas e indica la versión de Windows, la versión de PowerShell y los resultados.
4. Envía un pull request con una descripción del cambio y su validación.

Antes de publicar capturas o registros, elimina nombres de usuario, nombres de equipos y otros datos sensibles.

## Licencia

Este proyecto se distribuye bajo la **licencia MIT**. Consulta el archivo [LICENSE](LICENSE) para conocer sus términos.
