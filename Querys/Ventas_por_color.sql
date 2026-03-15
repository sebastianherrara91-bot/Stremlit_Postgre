WITH Valid_Marca_Tipo AS (
    SELECT
        COALESCE(MS.marca, MA.new_marca, EC.marca) AS vmt_marca
        ,M.tipo AS vmt_tipo
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.marca_subclase AS MS ON ST.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE ST.ini_cliente = :ini_cliente AND ST.fecha = :fecha_fin
    GROUP BY 1, 2
    HAVING SUM(ST.cant) >= :stock_threshold
)
SELECT
    sub.ini_cliente AS "Ini_Cliente"
    ,sub.tipo_calc AS "Tipo_Programa"
    ,sub.c_l AS "C_L"
    ,sub.local AS "Local"
    ,sub.ciudad AS "Ciudad"
    ,sub.marca_calc AS "Marca"
    ,to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') AS "Semanas"
    ,sub.fit_calc AS "Fit_Estilo"
    ,sub.color AS "Color"
    ,sub.c_color AS "C_Color"
    ,sub.color_hexa as "Color_Hexa"
    ,SUM(sub.v_cant) AS "Cant_Venta"
    ,SUM(sub.s_cant) AS "Cant_Stock"
FROM (
    SELECT
        ST.ini_cliente
        ,M.tipo as tipo_calc
        ,ST.num_local as c_l
        ,T.local
        ,T.tipo as tipo_tienda
        ,T.ciudad
        ,COALESCE(MS.marca, MA.new_marca, EC.marca) as marca_calc
        ,M.fit as fit_calc
        ,CO.color
        ,EC.cod_color as c_color
        ,CO.color_hexa as color_hexa
        ,(date_trunc('week', ST.fecha))::date as lunes_sem
        ,0 as v_cant
        ,ST.cant as s_cant
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    INNER JOIN dbo.tiendas AS T ON ST.num_local = T.codigo AND T.ini_cliente = ST.ini_cliente AND T.tipo = 'TIENDA'
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.cod_color AS CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.marca_subclase AS MS ON ST.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE ST.ini_cliente = :ini_cliente AND ST.fecha BETWEEN :fecha_inicio_stock AND :fecha_fin

    UNION ALL

    SELECT
        VT.ini_cliente
        ,M.tipo as tipo_calc
        ,VT.num_local as c_l
        ,T.local
        ,T.tipo as tipo_tienda
        ,T.ciudad
        ,COALESCE(MS.marca, MA.new_marca, EC.marca) as marca_calc
        ,M.fit as fit_calc
        ,CO.color
        ,EC.cod_color as c_color
        ,CO.color_hexa as color_hexa
        ,(date_trunc('week', VT.fecha))::date as lunes_sem
        ,VT.cant as v_cant
        ,0 as s_cant
    FROM dbo.dwh_ventas AS VT
    LEFT JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
    INNER JOIN dbo.tiendas AS T ON VT.num_local = T.codigo AND T.ini_cliente = VT.ini_cliente AND T.tipo = 'TIENDA'
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.cod_color AS CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.marca_subclase AS MS ON VT.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE VT.ini_cliente = :ini_cliente AND VT.fecha BETWEEN :fecha_inicio AND :fecha_fin
) AS sub
INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_marca = sub.marca_calc AND VMT.vmt_tipo = sub.tipo_calc
LEFT JOIN dbo.semanas SEM ON sub.lunes_sem = SEM.dia_inicio
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11;