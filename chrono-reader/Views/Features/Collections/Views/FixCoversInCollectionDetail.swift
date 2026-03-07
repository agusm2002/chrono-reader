// FixCoversInCollectionDetail.swift
//
// INSTRUCCIONES PARA CORREGIR PORTADAS GRANDES EN VISTA DETALLE
//
// En el archivo CollectionRowView.swift, necesitas modificar cómo se muestran las portadas
// en la vista detalle de colección. Hay un bug con las portadas que no tienen formato vertical
// estándar o son de doble página, que hace que se vean demasiado grandes.
//
// PASO 1: Encuentra esta sección en CollectionRowView.swift, dentro de CollectionDetailView:
/*
   VStack(alignment: .leading, spacing: 8) {
       // Portada del libro con gesto de toque
       bookCover(for: book)
           .aspectRatio(2/3, contentMode: .fit)
           .cornerRadius(8)
           .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
*/

// PASO 2: Reemplaza esa parte por el siguiente código:
/*
   VStack(alignment: .leading, spacing: 8) {
       // Portada del libro con gesto de toque
       Group {
           bookCover(for: book)
               .scaledToFill()
               .clipped()
       }
       .frame(minWidth: 0, maxWidth: .infinity)
       .aspectRatio(2/3, contentMode: .fit)
       .clipShape(RoundedRectangle(cornerRadius: 8))
       .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
*/

// Esta modificación asegura que todas las portadas:
// 1. Sean recortadas correctamente al formato deseado (2/3)
// 2. No se desborden de sus contenedores
// 3. Se vean consistentes independientemente de las proporciones originales

// NOTA: La función bookCover ya tiene las correcciones necesarias (aspectRatio:.fill y .clipped),
// pero es necesario aplicar restricciones adicionales en la vista detalle. 