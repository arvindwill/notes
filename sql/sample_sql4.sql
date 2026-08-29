SELECT 
    s.areaname AS areaName,
    s.id AS areaId,
    COALESCE(SUM(fgm.added), 0) AS added,
    COALESCE(SUM(fgm.prevBal), 0) AS prevBal,
    COALESCE(SUM(fgm.paid), 0) AS paid,
    COALESCE(SUM(fgm.balance), 0) AS balance,
    COALESCE(SUM(fgm.dividend), 0) AS dividend,
    COALESCE(SUM(fgm.runningBal), 0) AS runningBal,
    COALESCE(SUM(fgm.runningBalValue), 0) AS runningBalValue,
    br.name AS officeBranchName
FROM tbl_area s
LEFT JOIN tbl_branch br ON br.id = s.branch_id
LEFT JOIN (
    SELECT 
        m.name AS memberName,
        g.duration,
        ((g.emdue * gm.tkt_percentage) / 100) AS emDue,
        ra.runningBal,
        ra1.runningBalValue,
        g.amount AS chitAmount,
        gm.id AS groupMemberId,
        m.fcno AS fcNo,
        m.mapped_phone AS phoneNo,
        gm.tktno AS ticketNo,
        g.id AS groupId,
        g.groupno AS groupNo,
        m.id AS memberId,
        m.area_id AS areaid,
        COALESCE(ade.arrears, 0) AS added,
        COALESCE(pre.arrears, 0) AS prevBal,
        COALESCE(pa.credit_value, 0) AS paid,
        COALESCE(divi.dividend, 0) AS dividend,
        (CASE WHEN minInstNo = maxInstNo THEN minInstNo ELSE CONCAT(minInstNo, '-', maxInstNo) END) AS pendingInstNo,
        CASE WHEN g.DURATION - maxInstNo = 0 
            THEN 'Finished' 
            ELSE 
                CASE WHEN IFNULL((
                    SELECT MAX(ae.installno) 
                    FROM tbl_auction_member_detail ae 
                    INNER JOIN tbl_auction_entry au ON au.id = ae.auctionentryid AND ae.is_prizedmember = 1 
                    WHERE ae.groupid = g.id AND ae.TKTNO = gm.TKTNO AND ae.tkt_suffix = gm.tkt_suffix 
                      AND ae.is_active = 1 AND (DATE(au.auctiondate) <= ?)
                ), 0) > 0 
                THEN 'Prized' 
                ELSE 'Not Prized' 
                END 
        END AS bitOpt,
        CASE WHEN COALESCE(ade.arrears, 0) + COALESCE(pre.arrears, 0) - COALESCE(pa.credit_value, 0) > 0 
            THEN COALESCE(ade.arrears, 0) + COALESCE(pre.arrears, 0) - COALESCE(pa.credit_value, 0) 
            ELSE 0 
        END AS balance
    FROM tbl_group_member gm
    INNER JOIN tbl_group_new AS g ON g.id = gm.groupid AND gm.active_tkt = 1 AND g.is_active = 1 AND gm.is_active = 1
    INNER JOIN tbl_member AS m ON m.id = gm.memberid
    LEFT JOIN tbl_area s ON s.id = m.area_id

    LEFT JOIN (
        SELECT 
            gm.groupid, gm.tktno, gm.tkt_suffix,
            ((COALESCE(SUM(a1.dividend), 0) * gm.tkt_percentage) / 100) AS dividend,
            (CASE WHEN ? = 1 
                THEN ((SUM(gm.emdue) * gm.tkt_percentage) / 100) 
                ELSE ((COALESCE(SUM(gm.emdue), 0) * gm.tkt_percentage) / 100) - ((COALESCE(SUM(a1.dividend), 0) * gm.tkt_percentage) / 100) 
            END) AS arrears
        FROM tbl_group_member gm
        INNER JOIN tbl_auction_entry a ON a.groupid = gm.groupid AND gm.active_tkt = 1 AND a.is_active = 1
        LEFT JOIN tbl_auction_entry a1 ON a1.groupid = a.groupid AND a.installno = a1.dividend_for AND a1.is_active = 1
        WHERE (DATE(a.auctiondate) >= ?) AND (DATE(a.auctiondate) <= ?)
        GROUP BY gm.groupid, gm.tktno, gm.tkt_suffix
    ) AS ade ON ade.groupid = gm.groupid AND ade.tktno = gm.tktno AND ade.tkt_suffix = gm.tkt_suffix

    LEFT JOIN (
        SELECT 
            gm.groupid, gm.tktno, gm.tkt_suffix,
            ((COALESCE(SUM(a1.dividend), 0) * gm.tkt_percentage) / 100) AS dividend,
            (CASE WHEN ? = 1 
                THEN ((SUM(gm.emdue) * gm.tkt_percentage) / 100) 
                ELSE ((COALESCE(SUM(gm.emdue), 0) * gm.tkt_percentage) / 100) - ((COALESCE(SUM(a1.dividend), 0) * gm.tkt_percentage) / 100) 
            END) AS arrears
        FROM tbl_group_member gm
        INNER JOIN tbl_auction_entry a ON a.groupid = gm.groupid AND gm.active_tkt = 1 AND a.is_active = 1
        LEFT JOIN tbl_auction_entry a1 ON a1.groupid = a.groupid AND a.installno = a1.dividend_for AND a1.is_active = 1
        WHERE NOT EXISTS (
            SELECT chr.id FROM tbl_chit_receipt chr 
            WHERE chr.installfrom <= a.installno AND chr.installto >= a.installno 
              AND gm.groupid = chr.groupid AND gm.tktno = chr.tktno AND gm.tkt_suffix = chr.tkt_suffix 
              AND chr.is_active = 1 AND chr.date < ?
        )
        AND (DATE(a.auctiondate) < ?)
        GROUP BY gm.groupid, gm.tktno, gm.tkt_suffix
    ) AS pre ON pre.groupid = gm.groupid AND pre.tktno = gm.tktno AND pre.tkt_suffix = gm.tkt_suffix

    LEFT JOIN (
        SELECT 
            gm.groupid, gm.tktno, gm.tkt_suffix, 
            COALESCE(SUM(credit_value), 0) AS credit_value 
        FROM tbl_chit_receipt cr
        INNER JOIN tbl_group_member AS gm ON gm.groupid = cr.groupid AND gm.tktno = cr.tktno AND cr.tkt_suffix = gm.tkt_suffix AND gm.active_tkt = 1
        WHERE (DATE(date) >= ?) AND (DATE(date) <= ?) AND cr.is_active = 1
        GROUP BY gm.groupid, gm.tktno, gm.tkt_suffix
    ) AS pa ON pa.groupid = gm.groupid AND pa.tktno = gm.tktno AND pa.tkt_suffix = gm.tkt_suffix

    LEFT JOIN (
        SELECT 
            gm.groupid, gm.tktno, gm.tkt_suffix,
            ((COALESCE(SUM(a1.dividend), 0) * gm.tkt_percentage) / 100) AS dividend,
            (CASE WHEN ? = 1 
                THEN ((SUM(gm.emdue) * gm.tkt_percentage) / 100) 
                ELSE ((COALESCE(SUM(gm.emdue), 0) * gm.tkt_percentage) / 100) - ((COALESCE(SUM(a1.dividend), 0) * gm.tkt_percentage) / 100) 
            END) AS arrears
        FROM tbl_group_member gm
        INNER JOIN tbl_auction_entry a ON a.groupid = gm.groupid AND gm.active_tkt = 1 AND a.is_active = 1
        LEFT JOIN tbl_auction_entry a1 ON a1.groupid = a.groupid AND a.installno = a1.dividend_for AND a1.is_active = 1
        WHERE NOT EXISTS (
            SELECT chr.id FROM tbl_chit_receipt chr 
            WHERE chr.installfrom <= a.installno AND chr.installto >= a.installno 
              AND gm.groupid = chr.groupid AND gm.tktno = chr.tktno AND gm.tkt_suffix = chr.tkt_suffix 
              AND chr.is_active = 1 AND chr.date <= ?
        )
        AND (DATE(a.auctiondate) <= ?)
        GROUP BY gm.groupid, gm.tktno, gm.tkt_suffix
    ) AS divi ON divi.groupid = gm.groupid AND divi.tktno = gm.tktno AND divi.tkt_suffix = gm.tkt_suffix

    LEFT JOIN (
        SELECT 
            gm.groupid, gm.tktno, gm.tkt_suffix,
            ((COALESCE(SUM(a1.dividend), 0) * gm.tkt_percentage) / 100) AS dividend,
            MAX(a.installno) AS maxInstNo,
            MIN(a.installno) AS minInstNo,
            (CASE WHEN ? = 1 
                THEN ((SUM(gm.emdue) * gm.tkt_percentage) / 100) 
                ELSE ((COALESCE(SUM(gm.emdue), 0) * gm.tkt_percentage) / 100) - ((COALESCE(SUM(a1.dividend), 0) * gm.tkt_percentage) / 100) 
            END) AS arrears
        FROM tbl_group_member gm
        INNER JOIN tbl_auction_entry a ON a.groupid = gm.groupid AND gm.active_tkt = 1 AND a.is_active = 1
        LEFT JOIN tbl_auction_entry a1 ON a1.groupid = a.groupid AND a.installno = a1.dividend_for AND a1.is_active = 1
        WHERE NOT EXISTS (
            SELECT chr.id FROM tbl_chit_receipt chr 
            WHERE chr.installfrom <= a.installno AND chr.installto >= a.installno 
              AND gm.groupid = chr.groupid AND gm.tktno = chr.tktno AND gm.tkt_suffix = chr.tkt_suffix 
              AND chr.is_active = 1 AND chr.date <= ?
        )
        AND (DATE(a.auctiondate) <= ?)
        GROUP BY gm.groupid, gm.tktno, gm.tkt_suffix
    ) AS pres ON pres.groupid = gm.groupid AND pres.tktno = gm.tktno AND pres.tkt_suffix = gm.tkt_suffix

    LEFT JOIN (
        SELECT 
            group_member_id, group_id, ticket_no, tkt_suffix, member_id, 
            COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0) AS runningBal 
        FROM tbl_running_account ra 
        WHERE ra.is_active = 1 
        GROUP BY group_id, ticket_no, tkt_suffix, member_id
    ) AS ra ON ra.group_id = gm.groupid AND ra.ticket_no = gm.tktno AND ra.tkt_suffix = gm.tkt_suffix AND ra.member_id = gm.memberid

    LEFT JOIN (
        SELECT 
            group_member_id, group_id, ticket_no, tkt_suffix, member_id, 
            COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0) AS runningBalValue 
        FROM tbl_running_account ra 
        WHERE ra.is_active = 1 AND transaction_date <= ? 
        GROUP BY group_id, ticket_no, tkt_suffix, member_id
    ) AS ra1 ON ra1.group_id = gm.groupid AND ra1.ticket_no = gm.tktno AND ra1.tkt_suffix = gm.tkt_suffix AND ra1.member_id = gm.memberid

    WHERE m.is_active = 1
) AS fgm ON fgm.areaid = s.id

WHERE s.is_active = 1
  AND (? IS NULL OR s.id IN (?, ?, ...))
  AND (s.branch_id = ? OR ? = 0)
GROUP BY s.id
ORDER BY s.areaname;


