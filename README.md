# Análisis de Churn — Fintech Colombia (COFINFAD)
## Proyecto Analista de Datos Jr.

**Tabla analizada:** `public.customer_data`
**Herramienta:** PostgreSQL (pgAdmin)
**Sector:** Fintech
**Fuente del dataset:** COFINFAD — Colombian Fintech Financial Analytics Dataset (Muñoz Guerrero, Ceballos & Trejos Rojas, 2024, Hugging Face)
**Tamaño:** 48,723 clientes · 3,159,157 transacciones · periodo enero–diciembre 2023 · moneda COP
**Nota:** este es un dataset sintético/anonimizado con fines de investigación académica, no datos operacionales reales de una fintech.

## Resumen

Antes de iniciar el análisis exploratorio, se realizó un proceso de limpieza y validación de calidad de datos sobre la tabla `customer_data`, cubriendo cuatro frentes: duplicados, valores nulos, errores de escritura (misspellings) y consistencia de formatos/tipos de datos.

---

## 2. Limpieza de datos

### 2.1 Detección de duplicados

Se verificó si existían filas con el mismo contenido en todas las columnas excepto la Primary Key (`customer_id`), lo cual indicaría un posible error de carga de datos duplicada.

```sql
SELECT column1, column2, column3, COUNT(*) AS cantidad
FROM public.customer_data
GROUP BY column1, column2, column3
HAVING COUNT(*) > 1;
```

**Hallazgo:** No se encontraron duplicados

---

### 2.2 Valores nulos

Se generó un diagnóstico automático de nulos por columna usando `information_schema.columns` junto con `string_agg`, para no tener que revisar columna por columna manualmente.

Se encontraron valores nulos en 3 columnas, cada una tratada según su significado real de negocio (no se eliminaron filas):

| Columna | Causa del nulo | Decisión tomada | Justificación |
|---|---|---|---|
| `credit_utilization_ratio` | Cliente no tiene tarjeta de crédito | Se dejó como `NULL` | Es un nulo **estructural**, no un dato faltante. Rellenarlo con 0 sería engañoso, ya que 0% de utilización implica tener tarjeta y no usarla — algo distinto a no tenerla. Ya existe la columna `credit_card` (Sí/No) que explica el nulo. |
| `feature_requests` | Cliente no hizo ninguna solicitud | Se reemplazó con `'Sin solicitud'` | Convierte la ausencia de dato en una categoría analizable. |
| `complaint_topics` | Cliente no presentó ninguna queja | Se reemplazó con `'Sin queja'` | Mismo criterio que `feature_requests`. |

```sql
UPDATE public.customer_data
SET
	feature_requests = COALESCE(feature_requests, 'Sin solicitud'),
	complaint_topics = COALESCE(complaint_topics, 'Sin queja');
```

---

### 2.3 Errores de escritura (misspellings) y consistencia categórica

Se priorizó la revisión en columnas categóricas de bajo cardinal (pocas opciones posibles), ya que ahí el impacto de inconsistencias es mayor y más fácil de corregir:

- `gender`, `location`, `income_bracket`, `occupation`, `education_level`, `marital_status`, `acquisition_channel`, `customer_segment`, `clv_segment`

```sql
SELECT columna, COUNT(*) AS cantidad
FROM public.customer_data
GROUP BY columna
ORDER BY columna;
```

**Hallazgo:** No se encontraton inconsistencias

No se aplicó corrección ortográfica exhaustiva a las columnas de texto libre (`feature_requests`, `complaint_topics`), ya que su valor analítico está en la categorización temática del contenido, no en la ortografía perfecta.

---

### 2.4 Validación de formatos y tipos de datos

Se verificó que cada columna tuviera el tipo de dato correcto (`integer`, `bigint`, `numeric`, `date`, `text`) usando `information_schema.columns`, para asegurar que las columnas numéricas y de fecha permitan cálculos correctos más adelante.

**Hallazgo:** Todas las columnas tenian el formato correcto

---

### 2.5 Columnas redundantes con nombres similares

Se detectaron varios pares de columnas cuyo nombre sugiere que miden lo mismo. Se investigó cada par comparando sus valores directamente en SQL:

| Par de columnas | ¿Idénticas? | Decisión |
|---|---|---|
| `first_tx` vs `first_transaction_date` | **Sí**, 100% idénticas en todas las filas (0 diferencias detectadas) | Se eliminó `first_tx`, se conservó `first_transaction_date` por tener nombre más descriptivo |
| `last_tx` vs `last_transaction_date` | No — difieren en días, sin patrón fijo | Se conservaron ambas, pendiente de definir cuál usar según el análisis |
| `tx_count` vs `monthly_transaction_count` | No — no son la misma métrica (una es total acumulado, la otra un promedio mensual) | Se conservaron ambas, no son redundantes realmente |
| `avg_tx_value` vs `average_transaction_value` | No — sin relación matemática constante | Pendiente de investigar |
| `total_tx_volume` vs `total_transaction_volume` | No — la relación entre ambas varía por cliente (no es un factor fijo como x2) | Pendiente de investigar |

**Contexto importante:** según la documentación oficial del dataset (COFINFAD), estas son "características derivadas" generadas como parte del proceso de creación del dataset sintético, no columnas provenientes de fuentes de datos reales combinadas. Dado que el dataset es sintético y con fines académicos, se documenta esta inconsistencia como una **limitación conocida del dataset** en vez de intentar reconciliar su origen exacto — un comportamiento que en un dataset operacional real ameritaría escalarse al equipo de origen de datos.

---

## 3. Análisis exploratorio

Después de la limpieza, se realizó un análisis exploratorio utilizando Python y Power BI para estudiar la relación entre las características de los clientes y `churn_probability`.

### Principal hallazgo: adopción de productos

Una de las relaciones más claras encontradas fue entre el número de productos financieros activos y la probabilidad promedio de churn.

| Productos activos | Churn promedio |
|---|---|
| 1 | ~0,40 |
| 2 | ~0,35 |
| 3 | ~0,30 |
| 4 | ~0,25 |
| 5 | ~0,20 |

Los clientes con menor número de productos presentan una probabilidad promedio de churn considerablemente mayor.

Sin embargo, este análisis muestra una asociación y no una relación causal. No se puede concluir que aumentar el número de productos cause directamente una reducción del churn.

---

## 4. Análisis de Componentes Principales (PCA)

Se utilizó PCA para explorar la estructura de las variables numéricas e identificar las principales dimensiones de variabilidad presentes en el conjunto de datos.

La varianza explicada por los primeros componentes fue:

| Componente | Varianza explicada |
|---|---|
| PC1 | 13,67% |
| PC2 | 12,40% |
| PC3 | 8,51% |
| PC4 | 7,36% |
| PC5 | 7,08% |

Los primeros tres componentes explican conjuntamente el 34,58% de la varianza total.

El análisis de los loadings permitió identificar grupos de variables relacionadas con:

- Frecuencia de transacciones
- Satisfacción
- Volumen de transacciones
- Soporte al cliente
- Uso de funcionalidades

El PCA se utilizó principalmente como una herramienta exploratoria para comprender la estructura multivariada de los datos.

---

## 5. Segmentación de clientes mediante K-Means

Se utilizó el algoritmo K-Means para segmentar a los clientes utilizando dos variables:

- `customer_lifetime_value`
- `active_products`

Antes de aplicar el algoritmo, ambas variables fueron estandarizadas mediante `StandardScaler`.

```python
X = df[['customer_lifetime_value', 'active_products']]
X_scaled = StandardScaler().fit_transform(X)
```

Se evaluaron diferentes valores de k utilizando:

- Inercia
- Silhouette Score
- Tamaño de los clusters
- Interpretabilidad desde el punto de vista de negocio

La solución seleccionada fue de 6 segmentos, buscando un equilibrio entre separación estadística e interpretabilidad de los grupos.

Los identificadores numéricos generados por K-Means no tienen significado intrínseco. Por esta razón, los clusters fueron interpretados y nombrados posteriormente según sus características.

### Segmentos obtenidos

| Segmento | Clientes | Productos promedio | Churn promedio |
|---|---|---|---|
| Single-Product High-Risk Customers | 18.907 | 1,00 | 39,76% |
| Standard Customers - 2 Products | 14.119 | 2,00 | 34,80% |
| High-Value Customers | 1.374 | 1,99 | 34,29% |
| Exceptional-Value Customers | 252 | 2,08 | 33,24% |
| Standard Customers - 3 Products | 6.973 | 3,00 | 29,84% |
| High-Adoption Low-Risk Customers | 7.098 | 4,33 | 23,11% |

---

## 6. Análisis del riesgo económico

Para estimar la exposición económica asociada con la probabilidad de churn, se calculó:

```
Valor en riesgo estimado = Valor del cliente × Probabilidad de churn
```

El valor en riesgo estimado total fue de aproximadamente 5,45 billones.

Esta cifra no representa una predicción de pérdida financiera real. Es una estimación del valor económico ponderado por la probabilidad de churn.

### Segmento prioritario

El segmento **Single-Product High-Risk Customers** presenta la mayor relevancia desde el punto de vista del riesgo:

- 18.907 clientes
- 38,8% de los clientes
- 39,76% de churn promedio
- 4,13 billones de valor total
- 1,64 billones de valor en riesgo estimado

Este segmento concentra aproximadamente 30,1% del valor en riesgo estimado total.

---

## 7. Principales insights

**1. La adopción de productos está fuertemente asociada con el churn**

Los clientes con menos productos activos presentan una mayor probabilidad promedio de churn. Esta relación identifica la adopción de productos como una variable importante para investigar en estrategias de retención.

**2. Los clientes con un solo producto representan la principal prioridad**

Los clientes Single-Product High-Risk combinan una alta probabilidad de churn con una gran cantidad de clientes, por lo que representan el segmento más relevante en términos de riesgo agregado.

**3. Los clientes de alto valor requieren una estrategia diferenciada**

Los High-Value Customers representan una pequeña proporción de la base de clientes, pero concentran una proporción considerable del valor económico total. Por lo tanto, el número de clientes por sí solo no debería determinar la prioridad de las estrategias de retención.

**4. Los clientes con mayor adopción presentan menor churn**

El segmento High-Adoption Low-Risk Customers presenta el menor churn promedio y el mayor número promedio de productos activos. Sin embargo, no puede concluirse que aumentar el número de productos cause directamente una reducción del churn.

---

## 8. Recomendaciones de negocio

**Priorizar clientes con un solo producto**
Diseñar estrategias específicas de retención para clientes con un único producto activo, especialmente aquellos con una elevada probabilidad estimada de churn.

**Investigar la adopción de productos**
Analizar si los clientes que adquieren productos adicionales posteriormente presentan una reducción en su churn. Para demostrar causalidad sería necesario realizar un análisis longitudinal o un experimento controlado.

**Proteger a los clientes de alto valor**
Implementar estrategias diferenciadas de retención para clientes de alto valor, debido a que representan una cantidad pequeña de clientes pero concentran una parte significativa del valor económico.

**Analizar a los clientes de alta adopción**
Investigar qué características presentan los clientes con alta adopción de productos y bajo churn para identificar patrones que puedan ser replicados en otros segmentos.

---

## 9. Dashboard

El dashboard desarrollado en Power BI permite visualizar:

- Número de clientes
- Churn promedio
- Número promedio de productos activos
- Valor total de clientes
- Valor en riesgo estimado
- Churn promedio según número de productos
- Churn promedio por segmento
- Valor en riesgo estimado por segmento

---

## 10. Limitaciones

- `churn_probability` es una variable existente en el dataset; no se construyó un modelo predictivo de churn a partir de un historial real de abandono.
- Las correlaciones y los clusters permiten identificar asociaciones, pero no demuestran causalidad.
- Los resultados de K-Means dependen de las variables seleccionadas y del número de clusters utilizado.
- Los identificadores numéricos de K-Means son arbitrarios; los nombres de los segmentos fueron definidos posteriormente según sus características.
- El valor en riesgo es una estimación basada en probabilidades y no una predicción de pérdidas financieras reales.
- Las características del dataset pueden no representar completamente el comportamiento de clientes bancarios reales, por lo que los resultados no deberían generalizarse sin validación externa.

---

## 11. Herramientas utilizadas

- **PostgreSQL / pgAdmin:** limpieza y validación de datos
- **Python:** análisis y transformación de datos
- **Pandas:** manipulación de datos
- **Scikit-learn:** PCA, estandarización y K-Means
- **Matplotlib:** visualización exploratoria
- **Power BI:** dashboard y visualización de resultados
- **Git / GitHub:** control de versiones y documentación

---

## 12. Estructura del proyecto

```
customer-churn-analysis/
│
├── data/
│
├── notebooks/
│   └── churn_analysis.ipynb
│
├── sql/
│   └── data_cleaning.sql
│
├── powerbi/
│   └── churn_dashboard.pbix
│
├── outputs/
│   └── segment_summary.xlsx
│
├── README.md
└── requirements.txt
```
