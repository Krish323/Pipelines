SELECT mf.Id AS MemberFirmId ,
	mf.Code AS MemberFirmCode ,
	mf.[Name] AS MemberFirmName ,
	ISNULL(c.CasesCount, 0) AS CasesCount 
FROM config.MemberFirm mf 
LEFT JOIN ( SELECT c.MemberFirmId ,COUNT(0) AS CasesCount FROM [data].[Case] c GROUP BY c.MemberFirmId ) c ON c.MemberFirmId = mf.Id 
where ISNULL(c.CasesCount, 0) > 0
