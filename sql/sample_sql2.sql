SELECT 
    g.id AS groupId, 
    g.groupno AS groupNo, 
    b.name AS officeBranchName,
    SUM(gmb.debit) AS debit,
    SUM(gmb.credit) AS credit,
    SUM(dividendEx) AS dividend
FROM tbl_group_new AS g
LEFT JOIN tbl_branch AS b ON b.id = g.branchid
LEFT JOIN tbl_group_agr ga ON ga.groupid = g.id AND ga.is_active = 1
LEFT JOIN tbl_group_member AS gmem ON g.id = gmem.groupid AND gmem.is_active = 1
LEFT JOIN (
    SELECT gm1.groupid, gm1.tktno, gm1.tkt_suffix, newmem_joiningdate 
    FROM tbl_group_member_transfer AS gmt 
    LEFT JOIN tbl_group_member AS gm1 ON gm1.id = gmt.group_member_id 
    WHERE gm1.active_tkt = 0 AND newmem_joiningdate >= ? AND gmt.is_active = 1 
    GROUP BY groupId, tktno, tkt_suffix
) AS mgm ON gmem.groupid = mgm.groupId AND gmem.tktno = mgm.tktno AND gmem.tkt_suffix = mgm.tkt_suffix
LEFT JOIN (
    SELECT id, group_member_id, newmem_joiningdate, is_active, groupid, old_tktno, tkt_suffix 
    FROM tbl_group_member_transfer 
    WHERE is_active = 1 
    GROUP BY groupid, old_tktno, tkt_suffix
) AS tgm ON gmem.groupid = tgm.groupid AND gmem.tktno = tgm.old_tktno AND gmem.tkt_suffix = tgm.tkt_suffix
LEFT JOIN (
    SELECT group_id, member_id, tkt_no, tkt_suffix, joining_date 
    FROM tbl_group_member_transfer_members 
    WHERE is_active = 1
) AS tmgm ON gmem.groupid = tmgm.group_id AND gmem.memberid = tmgm.member_id AND gmem.tktno = tmgm.tkt_no AND gmem.tkt_suffix = tmgm.tkt_suffix
LEFT JOIN (
    SELECT 
        gm.tktno AS ticketNo, 
        gm.active_tkt, 
        gm.tkt_suffix AS tktSuffix, 
        gm.groupid AS groupId, 
        gm.tktno, 
        p.debitValue AS debitValue,
        CASE WHEN p.debitValue IS NULL 
            THEN (
                SELECT ae.maxaucdisc 
                FROM tbl_auction_member_detail ae 
                INNER JOIN tbl_auction_entry a ON a.id = ae.auctionentryid AND ae.is_prizedmember = 1 
                INNER JOIN tbl_group_new g ON ae.groupid = g.id
                WHERE gm.groupid = ae.groupid AND gm.tktno = ae.tktno AND gm.tkt_suffix = ae.tkt_suffix 
                  AND gm.active_tkt = 1 AND a.auctiondate <= ? AND ae.is_active = 1
            )
            ELSE (((g.emdue * gm.tkt_percentage) / 100) * (g.duration - CASE WHEN ((r1.maxInstNo) - (auctionInstall) > 0) THEN (auctionInstall) ELSE (r1.maxInstNo) END))
        END AS debit,
        CASE WHEN p.debitValue IS NULL 
            THEN (((g.emdue * gm.tkt_percentage) / 100) * CASE WHEN ((r1.maxInstNo) - (auctionInstall) > 0) THEN (auctionInstall) ELSE (r1.maxInstNo) END)
            ELSE 0 
        END AS credit,
        CASE WHEN ((COALESCE(r1.maxInstNo, 0)) - (COALESCE(auctionInstall, 0)) > 0) 
            THEN (((COALESCE(r1.maxInstNo, 0)) - (COALESCE(auctionInstall, 0))) * ((g.emdue * gm.tkt_percentage) / 100)) - COALESCE(exceessDivident, 0) 
            ELSE COALESCE(newdividend, 0) 
        END AS dividendEx
    FROM tbl_group_member gm
    INNER JOIN tbl_member m ON gm.memberid = m.id AND gm.is_active = 1
    INNER JOIN tbl_group_new g ON g.id = gm.groupid AND g.is_active = 1
    LEFT JOIN (
        SELECT cr.groupid, cr.tktno, cr.tkt_suffix, SUM(cr.credit_value) AS creditValue, MAX(installto) AS maxInstNo 
        FROM tbl_chit_receipt cr
        INNER JOIN tbl_group_new g ON g.id = cr.groupid 
        WHERE cr.date <= ? AND cr.is_active = 1 
        GROUP BY cr.groupid, cr.tktno, cr.tkt_suffix
    ) AS r1 ON r1.groupid = gm.groupid AND r1.tktno = gm.tktno AND r1.tkt_suffix = gm.tkt_suffix
    LEFT JOIN (
        SELECT MAX(dividend_for) AS auctionInstall, groupid 
        FROM tbl_auction_entry 
        WHERE is_active = 1 AND auctiondate <= ? 
        GROUP BY groupid
    ) AS aud ON aud.groupid = gm.groupid
    LEFT JOIN (
        SELECT 
            gm.groupid, gm.tktno, gm.tkt_suffix, 
            ((COALESCE((SUM(a.dividend)), 0) * gm.tkt_percentage) / 100) AS exceessDivident 
        FROM tbl_group_member gm 
        INNER JOIN tbl_group_new g ON g.id = gm.groupid AND gm.is_active = 1
        LEFT JOIN tbl_auction_entry a ON a.groupid = gm.groupid AND a.is_active = 1 
        WHERE a.dividend_for <= (
            SELECT MAX(installto) FROM tbl_chit_receipt chr 
            WHERE gm.groupid = chr.groupid AND gm.tktno = chr.tktno AND chr.tkt_suffix = gm.tkt_suffix 
              AND is_active = 1 AND chr.date <= ?
        ) 
        AND a.dividend_for > (
            SELECT MAX(dividend_for) FROM tbl_auction_entry chr 
            WHERE gm.groupid = chr.groupid AND is_active = 1 AND chr.auctiondate <= ?
        ) 
        GROUP BY gm.groupid, gm.tktno, gm.tkt_suffix
    ) AS exceessDivident ON exceessDivident.groupid = gm.groupid AND exceessDivident.tktno = gm.tktno AND exceessDivident.tkt_suffix = gm.tkt_suffix
    LEFT JOIN (
        SELECT 
            gm.groupid, gm.tktno, gm.tkt_suffix, 
            ((COALESCE((SUM(a.dividend)), 0) * gm.tkt_percentage) / 100) AS newdividend 
        FROM tbl_group_member gm 
        INNER JOIN tbl_group_new g ON g.id = gm.groupid AND gm.is_active = 1
        LEFT JOIN tbl_auction_entry a ON a.groupid = gm.groupid AND a.is_active = 1
        LEFT JOIN (
            SELECT gm1.groupid, gm1.tktno, gm1.tkt_suffix, newmem_joiningdate 
            FROM tbl_group_member_transfer AS gmt
            LEFT JOIN tbl_group_member AS gm1 ON gm1.id = gmt.group_member_id 
            WHERE active_tkt = 0 AND newmem_joiningdate >= ? AND gmt.is_active = 1 
            GROUP BY groupId, tktno, tkt_suffix
        ) AS mgm ON gm.groupId = mgm.groupId AND gm.tktno = mgm.tktno AND gm.tkt_suffix = mgm.tkt_suffix
        LEFT JOIN (
            SELECT id, group_member_id, newmem_joiningdate, is_active, groupid, old_tktno, tkt_suffix 
            FROM tbl_group_member_transfer 
            WHERE is_active = 1 
            GROUP BY groupid, old_tktno, tkt_suffix
        ) AS tgm ON gm.groupid = tgm.groupid AND gm.tktno = tgm.old_tktno AND gm.tkt_suffix = tgm.tkt_suffix
        LEFT JOIN (
            SELECT group_id, member_id, tkt_no, tkt_suffix, joining_date 
            FROM tbl_group_member_transfer_members 
            WHERE is_active = 1
        ) AS tmgm ON gm.groupId = tmgm.group_id AND gm.memberid = tmgm.member_id AND gm.tktno = tmgm.tkt_no AND gm.tkt_suffix = tmgm.tkt_suffix
        WHERE NOT EXISTS (
            SELECT chr.id, chr.installfrom, chr.installto, chr.group_member_id 
            FROM tbl_chit_receipt chr 
            WHERE chr.installfrom <= a.dividend_for AND chr.installto >= a.dividend_for 
              AND gm.groupid = chr.groupid AND gm.tktno = chr.tktno AND chr.tkt_suffix = gm.tkt_suffix 
              AND is_active = 1 AND chr.date <= ?
        ) 
        AND CASE WHEN tgm.newmem_joiningdate IS NULL AND mgm.newmem_joiningdate IS NOT NULL THEN gm.active_tkt = 0 
             ELSE CASE WHEN active_tkt = 0 AND tgm.newmem_joiningdate IS NULL AND tmgm.joining_date IS NULL THEN gm.active_tkt = 1 
                  ELSE CASE WHEN active_tkt = 0 AND tgm.id IS NOT NULL AND tgm.newmem_joiningdate <= ? THEN gm.active_tkt = 1 
                       ELSE CASE WHEN active_tkt = 1 AND tmgm.joining_date IS NOT NULL THEN tmgm.joining_date <= ? 
                            ELSE CASE WHEN active_tkt = 0 AND tmgm.joining_date IS NOT NULL THEN tmgm.joining_date <= ? 
                                 ELSE gm.is_active = 1 
                            END 
                       END 
                  END 
             END 
        END
        AND a.auctiondate <= ? 
        GROUP BY gm.groupid, gm.tktno, gm.tkt_suffix
    ) AS d ON d.groupid = gm.groupid AND d.tktno = gm.tktno AND d.tkt_suffix = gm.tkt_suffix
    LEFT JOIN (
        SELECT cp.groupid, cp.tktno, cp.tkt_suffix, (debit_value) AS debitValue 
        FROM tbl_chit_payment cp
        INNER JOIN tbl_auction_member_detail ae ON ae.groupid = cp.groupid AND ae.tktno = cp.tktno AND cp.tkt_suffix = ae.tkt_suffix AND ae.is_prizedmember = 1 AND ae.is_active = 1
        INNER JOIN tbl_auction_entry a ON a.id = ae.auctionentryid AND ae.is_prizedmember = 1
        WHERE cp.is_active = 1 AND a.auctiondate <= ? AND cp.date <= ?
    ) AS p ON p.groupid = gm.groupid AND p.tktno = gm.tktno AND p.tkt_suffix = gm.tkt_suffix
) AS gmb ON gmb.groupid = gmem.groupid AND gmb.tktno = gmem.tktno AND gmb.tktSuffix = gmem.tkt_suffix AND gmb.active_tkt = gmem.active_tkt

WHERE ((g.group_registered_or_not = 1 AND COALESCE(ga.id, 0) > 0) OR g.group_registered_or_not = 0)
  AND (g.branchid = ? OR ? = 0) 
  AND CASE WHEN tgm.newmem_joiningdate IS NULL AND mgm.newmem_joiningdate IS NOT NULL THEN gmem.active_tkt = 0 
       ELSE CASE WHEN gmem.active_tkt = 0 AND tgm.newmem_joiningdate IS NULL AND tmgm.joining_date IS NULL THEN gmem.active_tkt = 1 
            ELSE CASE WHEN gmem.active_tkt = 0 AND tgm.id IS NOT NULL AND tgm.newmem_joiningdate <= ? THEN gmem.active_tkt = 1 
                 ELSE CASE WHEN gmem.active_tkt = 1 AND tmgm.joining_date IS NOT NULL THEN tmgm.joining_date <= ? 
                      ELSE CASE WHEN gmem.active_tkt = 0 AND tmgm.joining_date IS NOT NULL THEN tmgm.joining_date <= ? 
                           ELSE gmem.is_active = 1 
                      END 
                 END 
            END 
       END 
  END
GROUP BY g.id 
ORDER BY CAST(g.groupno AS UNSIGNED) ASC, g.groupno ASC 
LIMIT ?, ?;

