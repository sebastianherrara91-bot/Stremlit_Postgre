WITH Valid_Marca_Tipo AS (
    SELECT
        COALESCE(MS.marca, MA.new_marca, EC.marca) AS vmt_marca,
        M.tipo AS vmt_tipo
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.marca_subclase AS MS ON ST.ini_cliente = MS.ini_cliente 
        AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE ST.ini_cliente = :ini_cliente AND ST.fecha = :fecha_fin
    GROUP BY 1, 2
    HAVING SUM(ST.cant) >= :stock_threshold
)
SELECT
    sub.ini_cliente AS "Ini_Cliente",
    sub.c_l AS "C_L",
    sub.local AS "Local",
    sub.ciudad AS "Ciudad",
    sub.marca_calc AS "Marca",
    sub.tipo_calc AS "Tipo_Programa",
    sub.fit_calc AS "Fit_Estilo",
    to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') AS "Semanas",
    SUM(sub.v_cant) AS "Cant_Venta",
    SUM(sub.s_cant) AS "Cant_Stock",
    ROUND(CASE WHEN SUM(sub.v_cant) = 0 THEN 0 ELSE SUM(sub.v_pvp) / NULLIF(SUM(sub.v_cant), 0) END, 0) AS "PVP_Prom"
FROM (
    -- BLOQUE STOCK
    SELECT
        ST.ini_cliente
        ,ST.num_local AS c_l
        ,T.local
        ,T.ciudad
        ,COALESCE(MS.marca, MA.new_marca, EC.marca) AS marca_calc
        ,M.tipo AS tipo_calc
        ,M.fit AS fit_calc
        ,(date_trunc('week', ST.fecha))::date AS lunes_sem
        ,0 AS v_cant
        ,ST.cant AS s_cant
        ,0 AS v_pvp
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    INNER JOIN dbo.tiendas AS T ON ST.num_local = T.codigo AND T.ini_cliente = ST.ini_cliente AND T.tipo = 'TIENDA'
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca_subclase AS MS ON ST.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE ST.ini_cliente = :ini_cliente AND ST.fecha BETWEEN :fecha_inicio_stock AND :fecha_fin

    UNION ALL

    -- BLOQUE VENTAS
    SELECT
        VT.ini_cliente
        ,VT.num_local AS c_l
        ,T.local
        ,T.ciudad
        ,COALESCE(MS.marca, MA.new_marca, EC.marca) AS marca_calc
        ,M.tipo AS tipo_calc
        ,M.fit AS fit_calc
        ,(date_trunc('week', VT.fecha))::date AS lunes_sem
        ,VT.cant AS v_cant
        ,0 AS s_cant
        ,(VT.cant * VT.pvp_unit) AS v_pvp
    FROM dbo.dwh_ventas AS VT
    LEFT JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
    INNER JOIN dbo.tiendas AS T ON VT.num_local = T.codigo AND T.ini_cliente = VT.ini_cliente AND T.tipo = 'TIENDA'
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca_subclase AS MS ON VT.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE VT.ini_cliente = :ini_cliente AND VT.fecha BETWEEN :fecha_inicio AND :fecha_fin
) AS sub
INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_marca = sub.marca_calc AND VMT.vmt_tipo = sub.tipo_calc
LEFT JOIN dbo.semanas SEM ON sub.lunes_sem = SEM.dia_inicio
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8;