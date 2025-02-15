local function FusionMaterialCountCheck(tp,sg,fc,sumtype,tp)
	for c in sg:Iter() do
		if c:HasFlagEffect(PSEUDO_CARD_FLAG) then
			local uid=c:GetFlagEffectLabel(ORIGINAL_CARD_UID_FLAG)
			local ct=sg:FilterCount(function(sc) return sc:GetFlagEffectLabel(ORIGINAL_CARD_UID_FLAG)==uid end,nil)
			if ct~=c:GetFlagEffectLabel(MATERIAL_COUNT_FLAG) then
				return false
			end
		end
	end
	return true
end
local function AddOrRemove(tc,sg,mg)
	local operation=sg:IsContains(tc) and Group.Sub or Group.Merge
	if tc:HasFlagEffect(ORIGINAL_CARD_UID_FLAG) then
		local uid=tc:GetFlagEffectLabel(ORIGINAL_CARD_UID_FLAG)
		local pg=Group.CreateGroup()
		if tc:IsPseudo() or (tc:IsNotPseudo() and sg:IsContains(tc)) then
			pg=mg:Filter(Card.IsPseudo,nil,uid)
		end
		if tc:IsNotPseudo() and sg:IsContains(tc) then
			pg:Merge(tc)
		elseif tc:IsNotPseudo() then
			sg:AddCard(tc)
		end
		operation(sg,pg)
	else
		operation(sg,tc)
	end
end
function Fusion.OperationMix(insf,sub,...)
	local funs={...}
	return	function(e,tp,eg,ep,ev,re,r,rp,gc,chkfnf,summonEff)
				Fusion.SummonEffect=summonEff
				local chkf=chkfnf&0xff
				local c=e:GetHandler()
				local tp=c:GetControler()
				local notfusion=(chkfnf&FUSPROC_NOTFUSION)~=0
				local contact=(chkfnf&FUSPROC_CONTACTFUS)~=0
				local cancelable=(chkfnf&(FUSPROC_CONTACTFUS|FUSPROC_CANCELABLE))~=0
				local listedmats=(chkfnf&FUSPROC_LISTEDMATS)~=0
				local sumtype=SUMMON_TYPE_FUSION|MATERIAL_FUSION
				if listedmats then
					sumtype=0
				elseif contact or notfusion then
					sumtype=MATERIAL_FUSION
				end
				local matcheck=e:GetValue()
				local sub=not listedmats and (sub or notfusion) and not contact
				local mg=eg:Filter(Fusion.ConditionFilterMix,c,c,sub,sub,contact,sumtype,matcheck,tp,table.unpack(funs))
				local mustg=Auxiliary.GetMustBeMaterialGroup(tp,eg,tp,c,mg,REASON_FUSION)
				if contact then mustg:Clear() end
				local sg=Group.CreateGroup()
				if gc then
					mustg:Merge(gc)
				end
				for tc in aux.Next(mustg) do
					sg:AddCard(tc)
					if not contact and tc:IsHasEffect(EFFECT_FUSION_MAT_RESTRICTION) then
						local eff={gc:GetCardEffect(EFFECT_FUSION_MAT_RESTRICTION)}
						for i=1,#eff do
							local f=eff[i]:GetValue()
							mg:Match(Auxiliary.HarmonizingMagFilter,tc,eff[i],f)
						end
					end
				end
				local p=tp
				local sfhchk=false
				if not contact and Duel.IsPlayerAffectedByEffect(tp,511004008) and Duel.SelectYesNo(1-tp,65) then
					p=1-tp
					Duel.ConfirmCards(1-tp,mg)
					if mg:IsExists(Card.IsLocation,1,nil,LOCATION_HAND) then sfhchk=true end
				end
				while #sg<#funs do
					Duel.Hint(HINT_SELECTMSG,p,HINTMSG_FMATERIAL)
					local tc=Group.SelectUnselect(mg:Filter(Fusion.SelectMix,sg,tp,mg,sg,mustg:Filter(aux.TRUE,sg),c,sub,sub,contact,sumtype,chkf,table.unpack(funs)),sg,p,false,cancelable and #sg==0,#funs,#funs)
					if not tc then break end
					if #mustg==0 or not mustg:IsContains(tc) then
						AddOrRemove(tc,sg,mg)
					end
				end
				if sfhchk then Duel.ShuffleHand(tp) end
				Duel.SetFusionMaterial(sg)
				Fusion.SummonEffect=nil
			end
end
function Fusion.OperationMixRep(insf,sub,fun1,minc,maxc,...)
	local funs={...}
	return	function(e,tp,eg,ep,ev,re,r,rp,gc,chkfnf,summonEff)
				Fusion.SummonEffect=summonEff
				local chkf=chkfnf&0xff
				local c=e:GetHandler()
				local tp=c:GetControler()
				local notfusion=(chkfnf&FUSPROC_NOTFUSION)~=0
				local contact=(chkfnf&FUSPROC_CONTACTFUS)~=0
				local cancelable=(chkfnf&(FUSPROC_CONTACTFUS|FUSPROC_CANCELABLE))~=0
				local listedmats=(chkfnf&FUSPROC_LISTEDMATS)~=0
				local sumtype=SUMMON_TYPE_FUSION|MATERIAL_FUSION
				if listedmats then
					sumtype=0
				elseif contact or notfusion then
					sumtype=MATERIAL_FUSION
				end
				local matcheck=e:GetValue()
				local sub=not listedmats and (sub or notfusion) and not contact
				local sg=Group.CreateGroup()
				local mg=eg:Filter(Fusion.ConditionFilterMix,c,c,sub,sub,contact,sumtype,matcheck,tp,fun1,table.unpack(funs))
				local mustg=Auxiliary.GetMustBeMaterialGroup(tp,eg,tp,c,mg,REASON_FUSION)
				if contact then mustg:Clear() end
				if not mg:Includes(mustg) or mustg:IsExists(aux.NOT(Card.IsCanBeFusionMaterial),1,nil,c,sumtype) then return returnAndClearSummonEffect(false) end
				if gc then
					mustg:Merge(gc)
				end
				sg:Merge(mustg)
				local p=tp
				local sfhchk=false
				if not contact and Duel.IsPlayerAffectedByEffect(tp,511004008) and Duel.SelectYesNo(1-tp,65) then
					p=1-tp
					Duel.ConfirmCards(1-tp,mg)
					if mg:IsExists(Card.IsLocation,1,nil,LOCATION_HAND) then sfhchk=true end
				end
				while #sg<maxc+#funs do
					local cg=mg:Filter(Fusion.SelectMixRep,sg,tp,mg,sg,mustg,c,sub,sub,contact,sumtype,chkf,fun1,minc,maxc,table.unpack(funs))
					if #cg==0 then break end
					local finish=Fusion.CheckMixRepGoal(tp,sg,mustg,c,sub,sub,contact,sumtype,chkf,fun1,minc,maxc,table.unpack(funs)) and not Fusion.CheckExact and not (Fusion.CheckMin and #sg<Fusion.CheckMin)
					finish=finish and (not FusionMaterialCountCheck or FusionMaterialCountCheck(tp,sg,c,sumtype,tp))
					local cancel=(cancelable and #sg==0)
					Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FMATERIAL)
					local tc=Group.SelectUnselect(cg,sg,p,finish,cancel)
					if not tc then break end
					if #mustg==0 or not mustg:IsContains(tc) then
						AddOrRemove(tc,sg,mg)
					end
				end
				if sfhchk then Duel.ShuffleHand(tp) end
				Duel.SetFusionMaterial(sg)
				Fusion.SummonEffect=nil
			end
end