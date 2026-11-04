-- Clean and standardize NYC DOB Job Filings data
-- One row per source job filing record

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
    SELECT
        * EXCEPT (
            filing_status,
            borough,
            postcode,
            zip,
            current_status_date,
            approved_date,
            first_permit_date,
            signoff_date
        ),

        -- Standardize filing status
        UPPER(TRIM(filing_status)) AS filing_status,

        -- Standardize borough to match the 311 staging data
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY')
                THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX')
                THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY')
                THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY')
                THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY')
                THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Combine and clean ZIP code fields
        CASE
            WHEN REGEXP_CONTAINS(
                COALESCE(NULLIF(TRIM(postcode), ''), NULLIF(TRIM(zip), ''), ''),
                r'^\d{5}(-\d{4})?$'
            )
            THEN COALESCE(NULLIF(TRIM(postcode), ''), NULLIF(TRIM(zip), ''))
            ELSE NULL
        END AS zip,

        -- Convert text dates to DATE
        COALESCE(
            SAFE_CAST(current_status_date AS DATE),
            SAFE.PARSE_DATE('%m/%d/%Y', current_status_date)
        ) AS current_status_date,

        COALESCE(
            SAFE_CAST(approved_date AS DATE),
            SAFE.PARSE_DATE('%m/%d/%Y', approved_date)
        ) AS approved_date,

        COALESCE(
            SAFE_CAST(first_permit_date AS DATE),
            SAFE.PARSE_DATE('%m/%d/%Y', first_permit_date)
        ) AS first_permit_date,

        COALESCE(
            SAFE_CAST(signoff_date AS DATE),
            SAFE.PARSE_DATE('%m/%d/%Y', signoff_date)
        ) AS signoff_date,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Keep records with a valid filing identifier
    WHERE job_filing_number IS NOT NULL
)

SELECT * FROM cleaned