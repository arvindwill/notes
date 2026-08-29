SELECT DISTINCT 
    CASE WHEN last_auction_date IS NOT NULL 
        THEN (SELECT firstauctiondate FROM tbl_group_auction ga WHERE ga.group_id = g.id AND ga.is_active = 1)
        ELSE last_auction_date 
    END AS date,
    CASE WHEN ? = 1 AND gm.groupid != -1 
        THEN CONCAT(gm.tktno, ' - ', gm.tkt_suffix, ' / ', gm.tkt_percentage, '%') 
        ELSE gm.tktno 
    END AS ticketNo,
    gm.memberid AS memberId,
    gm.groupid AS groupId,
    gm.id AS groupMemberId,
    m.name AS memberName,
    g.groupno AS groupNo,
    b.name AS officeBranchName,
    m.area_id AS areaId,
    m.area_name AS areaName,
    cr.creditValue,
    cp.debitValue,
    ((ae1.dividend * gm.tkt_percentage) / 100) AS divi,
    gm.tkt_suffix AS tktSuffix,
    gm.tkt_percentage AS tktPercentage,
    cr.creditValue + ((ae1.dividend * gm.tkt_percentage) / 100) AS creditV,
    val,
    (CASE WHEN lastCh.instNo = g.duration THEN NULL 
        ELSE (CASE WHEN gmt.newmem_joiningdate IS NOT NULL THEN gmt.newmem_joiningdate ELSE firstCh.auctiondate END) 
    END) AS firstAuctionDate,
    (CASE WHEN lastCh.instNo = g.duration THEN lastCh.auctiondate ELSE NULL END) AS lastAuctionDate,
    (CASE WHEN gmt.newmem_joiningdate IS NOT NULL THEN 1 ELSE 0 END) AS isMemberTransfer,
    CASE WHEN debitValue IS NULL THEN COALESCE(d.md, 0)
        ELSE ((g.duration - cr.creditValue) * ((g.emdue * gm.tkt_percentage) / 100)) 
    END AS debit,
    CASE WHEN debitValue IS NULL THEN cr.creditValue * ((g.emdue * gm.tkt_percentage) / 100)
        ELSE 0 
    END AS credit,
    ((COALESCE(cr.creditValue, 0) * ((g.emdue * gm.tkt_percentage) / 100)) - COALESCE(val, 0) - ((ae1.dividend * gm.tkt_percentage) / 100)) * -1 AS dividend,
    COALESCE(groupedData.totalDays, 0) AS totalLateDays,
    COALESCE(groupedData.totalLateFeeAmt, 0) AS totalInterest,
    COALESCE(ls.paidInterest, 0) AS paidInterest,
    COALESCE(ca.inst_no, 0) AS chitAdvancePaidDue,
    COALESCE(aey.installno, 0) AS paymentDue
FROM tbl_group_member gm
INNER JOIN tbl_group_new g ON g.id = gm.groupid AND gm.is_active = 1 AND gm.active_tkt = 1
LEFT JOIN tbl_branch AS b ON b.id = g.branchid
INNER JOIN tbl_member m ON m.id = gm.memberid
LEFT JOIN (
    SELECT * FROM tbl_group_member_transfer ORDER BY newmem_joiningdate DESC LIMIT 1
) AS gmt ON gmt.groupid = gm.groupid AND gmt.newmember_id = gm.memberid AND gmt.old_tktno = gm.tktno AND gmt.tkt_suffix = gm.tkt_suffix
LEFT JOIN (
    SELECT gm.id, gm.groupid, gm.tktno, gm.tkt_suffix, COALESCE(ae.maxaucdisc, 0) AS md 
    FROM tbl_group_member gm 
    LEFT JOIN tbl_auction_member_detail ae ON ae.groupid = gm.groupid AND ae.tktno = gm.tktno AND ae.tkt_suffix = gm.tkt_suffix AND ae.is_prizedmember = 1 AND ae.is_active = 1 AND gm.is_active = 1 AND gm.active_tkt = 1
    INNER JOIN tbl_auction_entry ay ON ay.id = ae.auctionentryid AND ay.auctiondate <= ?
) AS d ON d.id = gm.id
LEFT JOIN (
    SELECT groupid, tktno, tkt_suffix, SUM(debit_value) AS debitValue 
    FROM tbl_chit_payment 
    WHERE date <= ? AND is_active = 1 
    GROUP BY groupid, tktno, tkt_suffix
) AS cp ON cp.groupid = gm.groupid AND cp.tktno = gm.tktno AND cp.tkt_suffix = gm.tkt_suffix
LEFT JOIN (
    SELECT groupid, tktno, tkt_suffix, MAX(installto) AS creditValue 
    FROM tbl_chit_receipt 
    WHERE date <= ? AND is_active = 1 
    GROUP BY groupid, tktno, tkt_suffix
) AS cr ON cr.groupid = gm.groupid AND cr.tktno = gm.tktno AND cr.tkt_suffix = gm.tkt_suffix
LEFT JOIN (
    SELECT groupid, tktno, tkt_suffix, SUM(credit_value) AS val 
    FROM tbl_chit_receipt 
    WHERE date <= ? AND is_active = 1 
    GROUP BY groupid, tktno, tkt_suffix
) AS cr1 ON cr1.groupid = gm.groupid AND cr1.tktno = gm.tktno AND cr1.tkt_suffix = gm.tkt_suffix
LEFT JOIN (
    SELECT a.groupid, SUM(a1.dividend) AS dividend 
    FROM tbl_auction_entry a 
    LEFT JOIN tbl_auction_entry a1 ON a1.groupid = a.groupid AND a.installno = a1.dividend_for AND a1.is_active = 1 AND a.is_active = 1
    WHERE a.auctiondate <= ? 
    GROUP BY a.groupid
) AS ae1 ON ae1.groupid = g.id
LEFT JOIN (
    SELECT installno AS instNo, auctiondate, groupid 
    FROM tbl_auction_entry 
    WHERE id IN (
        SELECT id FROM (
            SELECT a.id FROM tbl_auction_entry AS a 
            INNER JOIN (SELECT MIN(id) AS id FROM tbl_auction_entry GROUP BY groupid) t ON a.id = t.id
        ) f
    )
) AS firstCh ON firstCh.groupid = g.id
LEFT JOIN (
    SELECT installno AS instNo, auctiondate, groupid 
    FROM tbl_auction_entry 
    WHERE id IN (
        SELECT id FROM (
            SELECT a.id FROM tbl_auction_entry AS a 
            INNER JOIN (SELECT MAX(id) AS id FROM tbl_auction_entry GROUP BY groupid) t ON a.id = t.id
        ) f
    )
) AS lastCh ON lastCh.groupid = g.id
LEFT JOIN tbl_auction_member_detail aumd ON aumd.groupid = gm.groupid AND aumd.tktno = gm.tktno AND aumd.tkt_suffix = gm.tkt_suffix AND aumd.is_prizedmember = 1 AND aumd.is_active = 1
LEFT JOIN tbl_auction_entry aey ON aey.is_active = 1 AND aey.id = aumd.auctionentryid
LEFT JOIN (
    SELECT group_id, tkt_no, tkt_suffix, member_id, inst_no 
    FROM tbl_chit_advance 
    WHERE is_active = 1 AND type = 'credit'
) AS ca ON ca.group_id = gm.groupid AND ca.tkt_no = gm.tktno AND ca.member_id = gm.memberid AND ca.tkt_suffix = gm.tkt_suffix
LEFT JOIN (
    SELECT clf.group_id, clf.ticket_no, clf.tkt_suffix, clf.member_id, SUM(clf.amount) AS paidInterest
    FROM tbl_chit_late_fee_detail clf
    INNER JOIN tbl_chit_late_fee cf ON cf.id = clf.chit_late_fee_id
    INNER JOIN tbl_group_new gr ON gr.id = clf.group_id
    WHERE (gr.id = ? OR ? = 0) AND (cf.date <= ? OR ? IS NULL)
    GROUP BY clf.group_id, clf.ticket_no, clf.tkt_suffix, clf.member_id
) AS ls ON ls.group_id = gm.groupid AND ls.ticket_no = gm.tktno AND ls.tkt_suffix = gm.tkt_suffix AND ls.member_id = gm.memberid
LEFT JOIN (
    SELECT gm.groupid AS groupId, gm.memberid AS memberId, gm.tktno AS ticketNo, gm.tkt_suffix,
        SUM(CASE WHEN 0 < (TIMESTAMPDIFF(DAY, ad.auctiondate,
                CASE WHEN cr.date IS NOT NULL THEN cr.date WHEN ? != '' THEN ? ELSE NOW() END))
            THEN (TIMESTAMPDIFF(DAY, ad.auctiondate,
                CASE WHEN cr.date IS NOT NULL THEN cr.date WHEN ? != '' THEN ? ELSE NOW() END)) 
            ELSE 0 END) AS totalDays,
        SUM(CASE WHEN 0 > TIMESTAMPDIFF(DAY, ad.auctiondate,
                CASE WHEN cr.date IS NOT NULL THEN cr.date WHEN ? != '' THEN ? ELSE NOW() END) THEN 0
            WHEN cl.installno < (CASE WHEN cr.installto IS NULL THEN cl.installno + 1 ELSE cr.installto END)
                THEN CAST(ROUND((((g.amount * gm.tkt_percentage) / 100) / g.duration) * ((COALESCE(gm.pm_late_fee_perc, 0) / 100) / 365) *
                    TIMESTAMPDIFF(DAY, ad.auctiondate,
                        CASE WHEN cr.date IS NOT NULL THEN cr.date WHEN ? != '' THEN ? ELSE NOW() END), 2) AS DECIMAL(30, 2))
            ELSE CAST(ROUND((((g.amount * gm.tkt_percentage) / 100) / g.duration) * ((COALESCE(gm.npm_late_fee_perc, 0) / 100) / 365) *
                    TIMESTAMPDIFF(DAY, ad.auctiondate, CASE WHEN cr.date IS NOT NULL THEN cr.date WHEN ? = '' THEN ? ELSE NOW() END), 2) AS DECIMAL(30, 2))
        END) AS totalLateFeeAmt
    FROM tbl_auction_entry ad
    INNER JOIN tbl_group_member gm ON gm.groupid = ad.groupid AND gm.is_active = 1 AND gm.active_tkt = 1
    LEFT JOIN tbl_chit_receipt cr ON cr.groupid = gm.groupid AND cr.tktno = gm.tktno AND gm.tkt_suffix = cr.tkt_suffix AND cr.installfrom <= ad.installno AND cr.installto >= ad.installno AND cr.is_active = 1
    INNER JOIN tbl_group_new g ON g.id = ad.groupid
    LEFT JOIN tbl_auction_member_detail aumd1 ON aumd1.groupid = gm.groupid AND aumd1.tktno = gm.tktno AND aumd1.tkt_suffix = gm.tkt_suffix AND aumd1.is_prizedmember = 1 AND aumd1.is_active = 1
    LEFT JOIN tbl_auction_entry cl ON cl.is_active = 1 AND cl.id = aumd1.auctionentryid
    WHERE (ad.auctiondate <= ? OR ? IS NULL) AND ad.is_active = 1
    GROUP BY gm.groupid, gm.memberid, gm.tktno, gm.tkt_suffix
) AS groupedData ON gm.groupid = groupedData.groupId AND gm.tktno = groupedData.ticketNo AND gm.tkt_suffix = groupedData.tkt_suffix AND gm.memberid = groupedData.memberId
WHERE (gm.groupid = ? OR ? = 0) 
  AND (m.fcno = ? OR ? = '') 
  AND (g.branchid = ? OR ? = 0) 
  AND (m.id = ? OR ? = 0)
  AND (m.name LIKE CONCAT('%', ?, '%') OR ? = '') 
  AND (g.id = ? OR ? = 0)  
  AND (REPLACE(g.groupno, '/', '') LIKE CONCAT('%', ?, '%') OR ? = '')
  AND (? IS NULL OR m.area_id IN (?, ?, ...))
ORDER BY CAST(g.groupno AS UNSIGNED) ASC, g.groupno ASC;

