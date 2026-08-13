-- Paso 1: Crear las columna nuevas (vacías) y renombrar location
ALTER TABLE public.customer_data
RENAME COLUMN location TO city TEXT;

ALTER TABLE public.customer_data
ADD COLUMN department TEXT;

ALTER TABLE public.customer_data
ADD COLUMN churn_risk_band TEXT;

-- Paso 2: Llenar la columna churn_risk_band con el cálculo
UPDATE public.customer_data
SET churn_risk_band = CASE
	WHEN churn_probability < 0.38 THEN 'low_risk'
	WHEN churn_probability < 0.45 AND churn_probability >= 0.38 THEN 'medium_risk'
	ELSE 'high_risk'
END;

-- Paso 3: Separar y llenar las columnas departament y city

UPDATE public.customer_data
SET
	department = TRIM(SPLIT_PART(city, ',', 2));

UPDATE public.customer_data
SET
	city = TRIM(SPLIT_PART(city, ',', 1))