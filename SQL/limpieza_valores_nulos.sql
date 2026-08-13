UPDATE public.customer_data
SET feature_requests = COALESCE(feature_requests, 'Without request');

UPDATE public.customer_data
SET complaint_topics = COALESCE(complaint_topics, 'Without request/Not given');
