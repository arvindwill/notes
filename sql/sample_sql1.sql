SELECT 
    s.id AS areaId,
    s.areaname AS areaName,
    COALESCE(runn.runbal, 0) AS runningBal,
    COALESCE(ro.others, 0) AS others,
    (-1) * COALESCE(ro.debit_others, 0) AS debitOthers,
    COALESCE(dd.dividend, 0) AS dividend,
    COALESCE(dd.amount, 0) AS amount,
    COALESCE(dd.lateFeeAmt, 0) AS lateFeeAmt,
    COALESCE(dd.balance, 0) AS balance,
    COALESCE(dd.arrear, 0) AS arrear,
    br.name AS officeBranchName
FROM tbl_area s
LEFT JOIN tbl_branch br 
    ON br.id = s.branch_id
LEFT JOIN (
    SELECT a.id AS areaid, a.areaname AS areaname, SUM(rb.runningBal) AS runbal
    FROM tbl_area a
    LEFT JOIN (
        SELECT DISTINCT 
            g.id AS groupId, g.groupno AS groupNo, m.area_id AS areaId, m.area_name AS areaName,
            m.id AS memberId, m.name AS memberName, gm.id AS groupMemberId, gm.tktno AS ticketNo,
            gm.tkt_suffix AS tktSuffix, COALESCE(ra.bal, 0) AS runningBal
        FROM tbl_chit_estimate ce
        INNER JOIN tbl_group_new g ON g.id = ce.groupid AND g.is_finished = 0
        INNER JOIN tbl_group_member gm ON g.id = gm.groupid AND gm.active_tkt = 1 AND gm.is_active = 1
        INNER JOIN tbl_member m ON m.id = gm.memberid
        LEFT JOIN (
            SELECT group_id, member_id, ticket_no, tkt_suffix,
                   (COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0)) AS bal
            FROM tbl_running_account
            WHERE transaction_date <= ?
              AND is_active = 1
              AND group_id != -1
            GROUP BY group_id, member_id, ticket_no, tkt_suffix
        ) AS ra 
            ON ra.group_id = gm.groupid 
           AND ra.member_id = gm.memberid 
           AND ra.ticket_no = gm.tktno 
           AND ra.tkt_suffix = gm.tkt_suffix
        WHERE ce.auctiondate <= ?
    ) AS rb 
        ON rb.areaId = a.id AND a.is_active = 1
    GROUP BY rb.areaId
) AS runn 
    ON runn.areaid = s.id
LEFT JOIN (
    SELECT a.id AS areaid, a.areaname AS areaname,
           SUM(rn.others) AS others,
           SUM(CASE WHEN rn.others < 0 THEN rn.others ELSE 0 END) AS debit_others
    FROM tbl_area a
    LEFT JOIN (
        SELECT DISTINCT m.id, m.area_id AS areaId, COALESCE(ra.others, 0) AS others
        FROM tbl_chit_estimate ce
        INNER JOIN tbl_group_new g ON g.id = ce.groupid
        INNER JOIN tbl_group_member gm ON g.id = gm.groupid AND gm.active_tkt = 1 AND gm.is_active = 1
        INNER JOIN tbl_member m ON m.id = gm.memberid
        LEFT JOIN (
            SELECT member_id,
                   (COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0)) AS others
            FROM tbl_running_account
            WHERE transaction_date <= ?
              AND is_active = 1
              AND group_id = -1
            GROUP BY member_id
        ) AS ra 
            ON ra.member_id = m.id
        WHERE ce.auctiondate <= ?
          AND m.is_active = 1
    ) AS rn 
        ON rn.areaId = a.id
    GROUP BY rn.areaId
) AS ro 
    ON ro.areaid = s.id
LEFT JOIN (
    SELECT a.id AS areaid, a.areaname AS areaname,
           COALESCE(SUM(aa.dividend), 0) AS dividend,
           COALESCE(SUM(aa.amount), 0) AS amount,
           COALESCE(SUM(aa.balance), 0) AS balance,
           COALESCE(SUM(aa.runningBal), 0) AS runbal,
           SUM(CASE WHEN aa.arrear > 0 THEN aa.arrear ELSE 0 END) AS arrear,
           COALESCE(SUM(aa.lateFeeAmt), 0) AS lateFeeAmt
    FROM tbl_area a
    LEFT JOIN (
        SELECT DISTINCT 
            divi.groupMemberId, divi.areaId AS areaId, divi.areaName, divi.memberId, divi.memberName,
            COALESCE(SUM(divi.dividend), 0) AS dividend,
            COALESCE(SUM(divi.amount), 0) AS amount,
            COALESCE(SUM(divi.balance), 0) AS balance,
            COALESCE(SUM(divi.lateFeeAmt), 0) AS lateFeeAmt,
            COALESCE(ra.bal, 0) AS runningBal,
            COALESCE(SUM(divi.balance), 0) - COALESCE(ra.bal, 0) AS arrear
        FROM tbl_group_member gm
        INNER JOIN (
            SELECT DISTINCT 
                g.id AS groupId, g.groupno AS groupNo, m.area_id AS areaId, m.area_name AS areaName,
                m.id AS memberId, m.name AS memberName, gm.id AS groupMemberId, gm.tktno AS ticketNo,
                gm.tkt_suffix AS tktSuffix, di.instNo, di.dividend AS dividend, di.auctionDate,
                di.amount AS amount, di.balance AS balance, di.lateFeeAmt AS lateFeeAmt
            FROM tbl_chit_estimate ce
            INNER JOIN tbl_group_new g ON g.id = ce.groupid AND g.is_finished = 0
            INNER JOIN tbl_group_member gm ON g.id = gm.groupid AND gm.active_tkt = 1 AND gm.is_active = 1
            INNER JOIN tbl_member m ON m.id = gm.memberid
            LEFT JOIN tbl_fc fc ON fc.id = m.fcno
            LEFT JOIN (
                SELECT DISTINCT 
                    ce.Instno AS instNo, 
                    ce.auctiondate AS auctionDate,
                    ((g.emdue * gm.tkt_percentage) / 100) - ((ce.dueamount * gm.tkt_percentage) / 100) AS dividend,
                    ((g.emdue * gm.tkt_percentage) / 100) AS amount,
                    ((ce.dueamount * gm.tkt_percentage) / 100) AS balance,
                    gm.id AS groupMemberId,
                    CASE 
                        WHEN ? = '' THEN 0.00
                        WHEN ? = 'N' AND gm.late_interest_option = 'Y' THEN
                            CASE 
                                WHEN 0 > TIMESTAMPDIFF(DAY, ce.auctiondate, ?) THEN 0
                                WHEN ce.Instno > (CASE WHEN cp.installment_no IS NULL THEN ce.Instno ELSE cp.installment_no END)
                                    THEN ROUND(CAST((((g.emdue * gm.tkt_percentage) / 100) * ? / 365
                                                * TIMESTAMPDIFF(DAY, ce.auctiondate, ?)) AS DECIMAL(30,2)))
                                ELSE ROUND(CAST((((g.emdue * gm.tkt_percentage) / 100) * ? / 365
                                                * TIMESTAMPDIFF(DAY, ce.auctiondate, ?)) AS DECIMAL(30,2)))
                            END
                        WHEN ? = 'Y' THEN
                            CASE 
                                WHEN 0 > TIMESTAMPDIFF(DAY, ce.auctiondate, ?) THEN 0
                                WHEN ce.Instno > (CASE WHEN cp.installment_no IS NULL THEN ce.Instno ELSE cp.installment_no END)
                                    THEN ROUND(CAST((((g.emdue * gm.tkt_percentage) / 100) * ? / 365
                                                * TIMESTAMPDIFF(DAY, ce.auctiondate, ?)) AS DECIMAL(30,2)))
                                ELSE ROUND(CAST((((g.emdue * gm.tkt_percentage) / 100) * ? / 365
                                                * TIMESTAMPDIFF(DAY, ce.auctiondate, ?)) AS DECIMAL(30,2)))
                            END
                        ELSE 0
                    END AS lateFeeAmt
                FROM tbl_chit_estimate ce
                INNER JOIN tbl_group_new g ON g.id = ce.groupid AND g.is_finished = 0
                INNER JOIN tbl_group_member gm ON g.id = gm.groupid AND gm.active_tkt = 1
                INNER JOIN tbl_member m ON m.id = gm.memberid
                LEFT JOIN tbl_chit_payment cp 
                    ON cp.groupid = gm.groupid AND cp.tktno = gm.tktno 
                   AND gm.tkt_suffix = cp.tkt_suffix AND cp.is_active = 1
                WHERE NOT EXISTS (
                    SELECT cr.id FROM tbl_chit_receipt cr
                    WHERE cr.is_active = 1 
                      AND cr.groupid = gm.groupid 
                      AND cr.tktno = gm.tktno 
                      AND cr.tkt_suffix = gm.tkt_suffix
                      AND cr.installfrom <= ce.Instno 
                      AND cr.installto >= ce.Instno 
                      AND cr.date <= ?
                )
                AND (ce.auctiondate <= ?)
            ) AS di 
                ON di.groupMemberId = gm.id
            WHERE ce.auctiondate <= ?
        ) AS divi 
            ON divi.groupMemberId = gm.id
        LEFT JOIN (
            SELECT group_id, member_id, ticket_no, tkt_suffix,
                   (COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0)) AS bal
            FROM tbl_running_account
            WHERE transaction_date <= ?
              AND is_active = 1
              AND group_id != -1
            GROUP BY group_id, member_id, ticket_no, tkt_suffix
        ) AS ra 
            ON ra.group_id = gm.groupid 
           AND ra.member_id = gm.memberid 
           AND ra.ticket_no = gm.tktno 
           AND ra.tkt_suffix = gm.tkt_suffix
        WHERE gm.active_tkt = 1 AND gm.is_active = 1
        GROUP BY divi.groupMemberId
    ) AS aa 
        ON aa.areaId = a.id
    GROUP BY a.id
) AS dd 
    ON dd.areaid = s.id
WHERE s.is_active = 1
  AND (s.branch_id = ? OR ? = 0)
ORDER BY s.areaname;

