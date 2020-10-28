%let wrds = wrds.wharton.upenn.edu 4016; 
options comamid=TCP remote=WRDS;
signon username=_prompt_;

/************************************************************************************
* STEP ONE: Extract Compustat data; 
************************************************************************************/
rsubmit;
data compx2;
   set comp.funda (keep = gvkey tic fyear fyr datadate SALE AT INDFMT DATAFMT POPSRC CONSOL at lt csho prcc_f CEQ DLC DLTT DD1 DD2 DD3 DD4 DD5 
                          IB XINT TXT SPI WCAP RE LT SALE DV NI SICH COGS XSGA CAPX DP/**SPLTICRM SIC**/); 
   if indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C';
   /** create begin and end dates of fiscal year**/
   format endfyr begfyr date9.;
   endfyr= datadate;
   begfyr= intnx('month',endfyr,-11,'beg');  /* intnx(interval, from, n, 'aligment') */
run;

proc sort; by gvkey endfyr; 
run;

/*** step 1a***
merge with the current SIC codes
***/
rsubmit;
proc sql;
  create table compx3 as select *, b.sic
  from compx2 as a, comp.names as b
  where a.gvkey = b.gvkey and
  year(a.datadate) le b.year2 and  year(a.datadate) ge b.year1;                
quit;

/*******************************************************************************************
* STEP TWO: Link GVKEYS to CRSP Identifiers;                                               *
* Use CCMXPF_LINKTABLE table to obtain CRSP identifiers for our subset of companies/dates; *
********************************************************************************************/
rsubmit;
libname temp '/sastemp1/assafe1';
data ccmxpf_linktable;
set temp.ccmxpf_linktable;
run;
rsubmit;
data ccmxpf_linktable1;
set ccmxpf_linktable ;
gvkey1=gvkey*1;
run;

data compx4;
set compx3;
gvkey1=gvkey*1;
run;
rsubmit;
proc sql;
  create table mydata as select *
  from compx4 as a, ccmxpf_linktable1 as b
  where a.gvkey1 = b.gvkey1 and
  b.LINKTYPE in ("LU","LC","LD","LN","LS","LX") and
  b.usedflag=1 and (b.LINKDT <= a.endfyr or b.LINKDT = .B) and (a.endfyr <= b.LINKENDDT or b.LINKENDDT = .E);                
quit;

/***************************************************************************************
* STEP THREE: Add CRSP Monthly price data;
***************************************************************************************/

/** OPTION 1: ANNUAL FILE. 
              Simple match at the end of the fiscal year **/
rsubmit;
proc sql;
    create table mydata2 as select *
    from mydata as a, crsp.msf as b
    where a.lpermno = b.permno 
    and month(a.endfyr)=month(b.date) 
    and year(a.endfyr)=year(b.date);
quit;

/** OPTION 2: MONTHLY FILE. 
              Match accounting data with fiscal yearends in month 't', 
              with CRSP return data from month 't+3' to month 't+14' (12 months) **/
rsubmit;
proc sql;
    create table mydata2 as select *
    from mydata as a, crsp.msf as b
    where a.lpermno = b.permno 
    and	intck('month',a.endfyr,b.date) between 6 and 17;
quit;

/***************************************************************************************
* STEP FOUR: Adding delisting returns
***************************************************************************************/
rsubmit;
proc sort data=mydata2; by permno date;     
run;

/** Transform '.' to '0' in the last month of the firm**/
rsubmit;
data mydata3;
set mydata2;
if ret=. then ret=0;
run;

/** Create a file that contains the delisting return (dlret)**/
rsubmit;
 proc sql;
  create table delist1 as 
  select a.permno,a.date,a.dlret,year(a.date) as year
    from crsp.mse as a
	where year(a.date) ge 1960
	and a.dlret                   
    group by a.permno;             
   run;

proc sort data=delist1; by permno date;
run;

/** Merge the delisting return file and the main file **/ 
rsubmit;   
 proc sql;
 create table mydata4 as
 select a.*,b.dlret
   from mydata3 as a left join delist1 as b
  on a.permno=b.permno;
  run;

/** Adding the delisting return to the last month return **/ 
rsubmit;
proc sort data=mydata4; by descending permno descending date;
run;

data mydata5;
set mydata4;
lc1=lag(permno);
if dlret=. then do ret1=ret;
end;
else do;
if permno=lc1 then do ret1=ret;
end;
else do ret1=(1+ret)*(1+dlret)-1;
end;
end;
drop lc1;
run;

proc sort data=mydata5; by permno date;
run;

/***************************************************************************************
* STEP FIVE: Creating variables;
***************************************************************************************/
rsubmit;
data file1;
set mydata5;
size=abs(prc)*shrout;
mtb=(size/1000)/ceq;
ebit=IB+XINT+TXT+SPI;
z_score=1.2*(WCAP/AT)+1.4*(RE/AT)+3.3*((IB+XINT+TXT+SPI)/AT)+
        0.6*((size/1000)/LT)+0.999*(SALE/AT);
Payout=DV/ebit;
run;

data file2;
set file1;
keep Gvkey1 Tic PERMNO CUSIP Fyear Cyear Fyr Begfyr Endfyr DATE COGS XSGA CAPX DP SALE
     AT CEQ Dlc Dltt DD1 DD2 DD3 DD4 DD5 HEXCD Size PRC RET RET1 MTB EBIT Z_score Payout SICH sic;
run;

/***************************************************************************************
* Adding data from Compustat querterly file ;
***************************************************************************************/
rsubmit;
data fileq1;
set comp.fundq (keep = gvkey fyearq fyr fqtr SALEQ COGSQ IBQ XINTQ TXTQ SPIQ LTQ ATQ NIQ CHEQ SEQQ TXDITCQ PSTKQ datadate); 
run;

data fileq2;
set fileq1;

lag_saleq=lag(saleq);
lag2_saleq=lag2(saleq);
lag3_saleq=lag3(saleq);
lag4_saleq=lag4(saleq);
lag5_saleq=lag5(saleq);
lag6_saleq=lag6(saleq);
lag7_saleq=lag7(saleq);
lag8_saleq=lag8(saleq);
lag8_gvkey=lag8(gvkey);
msaleq=(saleq + lag_saleq + lag2_saleq + lag3_saleq + lag4_saleq + lag5_saleq + lag6_saleq + lag7_saleq)/8;
vsaleq=((saleq-msaleq)**2 + (lag_saleq-msaleq)**2 + (lag2_saleq-msaleq)**2 + (lag3_saleq-msaleq)**2 + 
       (lag4_saleq-msaleq)**2 + (lag5_saleq-msaleq)**2 + (lag6_saleq-msaleq)**2 + (lag7_saleq-msaleq)**2)/8; 
if lag_saleq>0 and lag2_saleq>0 and lag3_saleq>0 and lag4_saleq>0 and lag5_saleq>0 and lag6_saleq>0 and lag7_saleq>0
then do;
lret1=log(saleq/lag_saleq);
lret2=log(lag_saleq/lag2_saleq);
lret3=log(lag2_saleq/lag3_saleq);
lret4=log(lag3_saleq/lag4_saleq);
lret5=log(lag4_saleq/lag5_saleq);
lret6=log(lag5_saleq/lag6_saleq);
lret7=log(lag6_saleq/lag7_saleq);
lret8=log(lag7_saleq/lag8_saleq);
mlogq=(lret1+lret2+lret3+lret4+lret5+lret6+lret7+lret8)/8;
vlogq=((lret1-mlogq)**2 + (lret2-mlogq)**2 + (lret3-mlogq)**2 + (lret4-mlogq)**2 + 
       (lret5-mlogq)**2 + (lret6-mlogq)**2 + (lret7-mlogq)**2 + (lret8-mlogq)**2)/8; 
end;
if gvkey=lag8_gvkey then do;
var_saleq=vsaleq;
sigma_saleq=sqrt(vlogq);
end;
run;

data fileq2a;
set fileq2;

gmq=saleq-cogsq;
lag_gmq=lag(gmq);
lag2_gmq=lag2(gmq);
lag3_gmq=lag3(gmq);
lag4_gmq=lag4(gmq);
lag5_gmq=lag5(gmq);
lag6_gmq=lag6(gmq);
lag7_gmq=lag7(gmq);
lag7_gvkey=lag7(gvkey);
mgmq=(gmq + lag_gmq + lag2_gmq + lag3_gmq + lag4_gmq + lag5_gmq + lag6_gmq + lag7_gmq)/8;
vgmq=((gmq-mgmq)**2 + (lag_gmq-mgmq)**2 + (lag2_gmq-mgmq)**2 + (lag3_gmq-mgmq)**2 + 
       (lag4_gmq-mgmq)**2 + (lag5_gmq-mgmq)**2 + (lag6_gmq-mgmq)**2 + (lag7_gmq-mgmq)**2)/8; 

if gvkey=lag7_gvkey then do;
sigma_gmq=sqrt(vgmq);
end;
run;

data fileq3;
set fileq2a;
gvkey1=gvkey*1;
run;

proc sql;
create table file3 as select a.*, b.saleq, b.var_saleq, b.sigma_saleq, sigma_gmq, b.LTQ, b.ATQ, b.NIQ, b.CHEQ, b.SEQQ, b.TXDITCQ, b.PSTKQ
from file2 as a left join fileq3 as b
on a.gvkey1 = b.gvkey1 and intck('month', b.datadate, a.date) between 3 and 5;
quit;

***************************************************************
* REMOVE "WEIRD" stuff
***************************************************************;
rsubmit;
proc sql;
create table mydata6 as select a.*, b.HSHRCD
from file3 as a left join crsp.msfhdr as b
on a.permno = b.permno;
quit;


data mydata7; set mydata6; 
if (HSHRCD > 14) or  (HSHRCD < 10) then delete; 
run;  

***************************************************************
* Craeting CHS score
***************************************************************;

/** Uploading the file with the s&p500 data (sp500) **/;
rsubmit;
libname temp '/sastemp1/assafe1';
data sp500;
set temp.sp500;
run;

/** Merging the sp500 file and the main file **/
rsubmit;
data sp1;
set mydata7;
year=year(date);
month=month(date);
if year ge 1981;
run;
rsubmit;
proc sql;
  create table S1 as
  select a.*,b.*
    from sp1 as a left join sp500 as b
    on a.year=b.year 
    and a.month=b.month;
 run;

/** Uploading the file with the daily returns standad deviations (stds4) **/;
rsubmit;
libname temp '/sastemp1/assafe1';
data stds4;
set temp.stds4;
run;

/** Merging the stds4 file and the main file **/
rsubmit;
proc sql;
  create table SD1 as
  select a.*,b.*
    from S1 as a, stds4 as b
    where a.permno=b.permno
    and a.year=b.year 
    and a.month=b.month;
 run;

/** Defining the CHS basic inputs **/
rsubmit;
libname temp '/sastemp1/assafe1';
data SD1;
set temp.SD1;
run;

rsubmit;
data CHS1;
set SD1;
NIMTA=NIQ/(LTQ+size/1000);
TLMTA=LTQ/(LTQ+size/1000);
CASHMTA=CHEQ/(LTQ+size/1000);
MB=(size/1000)/(SEQQ+0.1*(size/1000-SEQQ));
PRICE=log(abs(prc));
EXRET=log((1+ret)/(1+vwret));
RSIZE=log(size/spsize);
SIGMA=SD*(250**0.5);
run;

/** Trancating the variables **/
 
proc univariate data=CHS1;
var NIMTA TLMTA CASHMTA MB PRICE EXRET RSIZE SIGMA;
run;
rsubmit;
data CHS2;
set CHS1;
if NIMTA ge 0.02496196 and NIMTA ne . then NIMTA=0.02496196;
if NIMTA le -0.07296981 and NIMTA ne . then NIMTA=-0.07296981;
if TLMTA ge 0.91401789 and TLMTA ne . then TLMTA=0.91401789;
if TLMTA le 0.03860419 and TLMTA ne . then TLMTA=0.03860419;
if CASHMTA ge 3.80857E-01 and CASHMTA ne . then CASHMTA=3.80857E-01;
if CASHMTA le 2.19869E-03 and CASHMTA ne . then CASHMTA=2.19869E-03;
if MB ge 7 and MB ne . then MB=7;
if MB le 3.90647E-01 and MB ne . then MB= 3.90647E-01;
if PRICE ge 2.708 and PRICE ne . then PRICE=2.708;
if PRICE le -2.877E-01 and PRICE ne . then PRICE=-2.877E-01;
if EXRET ge 2.211E-01 and EXRET ne . then EXRET=2.211E-01;
if EXRET le -2.564E-01 and EXRET ne . then EXRET=-2.564E-01;
if RSIZE ge -6.90E+00 and RSIZE ne . then RSIZE=-6.90E+00;
if RSIZE le -1.37E+01 and RSIZE ne . then RSIZE=-1.37E+01;
if SIGMA ge 1.418E+00 and SIGMA ne . then SIGMA=1.418E+00;
if SIGMA le 1.390E-01 and SIGMA ne . then SIGMA= 1.390E-01;
run; 

proc sort data=CHS2;
by permno date;
run;

data CHS3;
set CHS2;

lc12=lag12(permno);

lM1=lag(NIMTA);
LM2=lag2(NIMTA);
LM3=lag3(NIMTA);
LM4=lag4(NIMTA);
LM5=lag5(NIMTA);
LM6=lag6(NIMTA);
LM7=lag7(NIMTA);
LM8=lag8(NIMTA);
LM9=lag9(NIMTA);
LM10=lag10(NIMTA);

lE1=lag(EXRET);
LE2=lag2(EXRET);
LE3=lag3(EXRET);
LE4=lag4(EXRET);
LE5=lag5(EXRET);
LE6=lag6(EXRET);
LE7=lag7(EXRET);
LE8=lag8(EXRET);
LE9=lag9(EXRET);
LE10=lag10(EXRET);
LE11=lag11(EXRET);
LE12=lag12(EXRET);

phi=2**(-1/3);
NIMTA_AVG=((1-phi**3)/(1-phi**12))*(LM1+phi*LM2+(phi**2)*LM3+(phi**3)*LM4+(phi**4)*LM5+(phi**5)*LM6+(phi**6)*LM7+(phi**7)*LM8
                                    +(phi**8)*LM9+(phi**9)*LM10);

EXRET_AVG=((1-phi)/(1-phi**12))*(LE1+phi*LE2+(phi**2)*LE3+(phi**3)*LE4+(phi**4)*LE5+(phi**5)*LE6+(phi**6)*LE7+(phi**7)*LE8
                                 +(phi**8)*LE9+(phi**9)*LE10+(phi**10)*LE11+(phi**11)*LE12);

if permno=lc12 then do;
NIMTAAVG=NIMTA_AVG;
EXRETAVG=EXRET_AVG;
end;
run;

/** CHS score **/
data CHS4;
set CHS3;
CHS=-9.164-20.264*NIMTAAVG+1.416*TLMTA-7.129*EXRETAVG+1.411*SIGMA-0.045*RSIZE-2.132*CASHMTA+0.075*MB-0.058*PRICE;
run;

/** Uploading the file with the four facors(factors) **/;
rsubmit;
libname temp '/sastemp1/assafe1';
data factors;
set temp.factors;
run;

/** Merging the factors file and the main file **/
rsubmit;
proc sql;
  create table CHS5 as
  select a.*,b.*
    from CHS4 as a left join factors as b
    on a.year=b.year 
    and a.month=b.month;
 run;

/** Past 6-month return with one month lag **/

proc sort data=CHS5;
by permno date;
run;

data CHS6;
set CHS5;

   l1=lag(ret);
   l2=lag2(ret);
   l3=lag3(ret);
   l4=lag4(ret);
   l5=lag5(ret);
   l6=lag6(ret);

   lp6=lag6(permno);

   if permno=lp6 then do;
 
   past_ret=(1+l1)*(1+l2)*(1+l3)*(1+l4)*(1+l5)*(1+l6)-1;

  end;	  
 run;

/** Forming the CHS portfolios **/

data CHS7;
set CHS6;

   lp1=lag(permno);
   lp2=lag2(permno);
   lp3=lag3(permno);
      
   lchs1=lag(CHS);
   lchs2=lag2(CHS);
   lchs3=lag3(CHS);

   lsize1=lag(size);
   lsize2=lag2(size);
   lsize3=lag3(size);

   lSEQQ1=lag(SEQQ);
   lSEQQ2=lag2(SEQQ);
   lSEQQ3=lag3(SEQQ);
    
   lsize1=lag(size);

if month=6 and permno=lp1 then do;
a_chs=lchs1; a_size=lsize1; a_SEQQ=lSEQQ1;
end;

if month=7 and permno=lp2 then do;
a_chs=lchs2; a_size=lsize2; a_SEQQ=lSEQQ2;  
end;

if month=8 and permno=lp3 then do;
a_chs=lchs3; a_size=lsize3; a_SEQQ=lSEQQ3; 
end;

if month=9 and permno=lp1 then do;
a_chs=lchs1; a_size=lsize1; a_SEQQ=lSEQQ1;  
end;

if month=10 and permno=lp2 then do;
a_chs=lchs2; a_size=lsize2; a_SEQQ=lSEQQ2;
end;

if month=11 and permno=lp3 then do;
a_chs=lchs3; a_size=lsize3; a_SEQQ=lSEQQ3;  
end;

if month=12 and permno=lp1 then do;
a_chs=lchs1; a_size=lsize1; a_SEQQ=lSEQQ1;  
end;

if month=1 and permno=lp2 then do;
a_chs=lchs2; a_size=lsize2; a_SEQQ=lSEQQ2;   
end;

if month=2 and permno=lp3 then do;
a_chs=lchs3; a_size=lsize3; a_SEQQ=lSEQQ3;  
end;

if month=3 and permno=lp1 then do;
a_chs=lchs1; a_size=lsize1; a_SEQQ=lSEQQ1;  
end;

if month=4 and permno=lp2 then do;
a_chs=lchs2; a_size=lsize2; a_SEQQ=lSEQQ2;    
end;

if month=5 and permno=lp3 then do;
a_chs=lchs3; a_size=lsize3; a_SEQQ=lSEQQ3;   
end;

a_MB=(a_size/1000)/a_SEQQ;

run;

/** Define lag size **/
data CHS8;
set CHS7;
 lagsize=lag(size);
 lp=lag(permno);
 if permno=lp then do;
 lsize=lagsize;
 end;	  
run;

/** Define excess return **/
data CHS9;
set CHS8;
ex_ret=ret1-rf;
run;

/** Ranking by CHS **/
proc sort data=CHS9;
by date a_CHS;
run;

data CHS10;
set CHS9;
if a_CHS ne .;
run;

rsubmit;
libname temp '/sastemp1/assafe1';
data CHS10;
set temp.CHS10_new;
run;

rsubmit;
proc rank groups=5 data=CHS10 out=CHS11;
var a_CHS;
ranks CHS_decile;
by date;
run;

proc sort data=CHS11;
by date CHS_decile;
run;

data CHS12;
set CHS11;
if CHS_decile le 1 then do;
D_CAT=1;
end;
else do;
if CHS_decile le 3 then do;
D_CAT=2;
end;
else do;
D_CAT=3;
end;
end;
run;

data M1;
set CHS12;
SIC2=SIC/100-MOD(SIC,100)/100;
mkt_rf=emkt; 
run;

proc sort data=M1;
by permno date;
run;


/** Rolling regressions to get beta **/

/** Uploading the rolling regression code ('rollingreg.sas') **/;
rsubmit;
%include '/sastemp1/assafe1/rollingreg.sas';

* Call macro;
%rollingreg(
data=M1, out_ds=rr1,
id=permno, date=date,
model_equation= ret= mkt_rf,
start_date=, end_date=,
freq=month, s=1, n=36);

data m1; set m1; drop mkt_rf; run;

proc sql;
create table m2 as
select m1.*, rr1.mkt_rf
from m1 left join rr1
on month(m1.date)=month(rr1.date2) and year(m1.date)=year(rr1.date2) and m1.permno=rr1.permno and rr1.regobs>20;
quit;

proc sort data=m2; by permno date; run;

data M6;
set M2;
beta1=mkt_rf; drop mkt_rf;
if beta1 ge 10 then beta1=. ;
if beta1 le -10 then beta1=.;
run;

/** upload the bond rates file **/
rsubmit;
libname temp '/sastemp1/assafe1';
data fred;
set temp.fred;
run;

rsubmit;
proc sql;
  create table M6a as
  select a.*,b.*
    from M6 as a left join fred as b
    on a.year=b.year 
    and a.month=b.month;
 run;

rsubmit;
data M6b;
set M6a;
if D_CAT=1 then RB=AAA;
if D_CAT=2 then RB=Baa;
if D_CAT=3 then RB=Baa_2;
run;

/** Cost of capital using CAPM **/
rsubmit;
data M7;
set M6b;
CC=Rf*12+beta1*0.06;
LVG=(DLC+DLTT)/AT;
if LVG<0 then LVG=0;
WACC_old=(1-LVG)*CC+LVG*RB*(1-0.35);
WACC=((1-LVG)*CC+LVG*RB)*(1-0.35);
MLVG=(DLC+DLTT)/(DLC+DLTT+size/1000);
run;

/** getting the other variables **/
data M7a;
set M7;
RE=CC;
Gross_margin=SALE-COGS;
CSR=CAPX/SALE;
DEP=DP;
DSR=DEP/SALE;
run;

/** Calculating industry averages **/
rsubmit;
proc univariate data=M7a;
var payout wacc_old wacc sigma_saleq sigma_gmq re rb rf dlc dltt lvg mlvg xsga sale cogs gross_margin capx csr dep dsr;
run;
rsubmit;
data M8;
set M7a;
if payout ge 5 then payout=.;
if payout le -5 then payout=.;
if wacc_old ge 1 then wacc_old=.;
if wacc_old < 0 then wacc_old=.;
if wacc ge 1 then wacc=.;
if wacc < 0 then wacc=.;
if sigma_saleq ge 2 then sigma_saleq=.;
if csr ge 3 then csr=.;
if csr < 0 then csr=.;
if dsr ge 3 then dsr=.;
if dsr < 0 then dsr=.;
run;

rsubmit;
proc sort data=M8;
by date sic2 d_cat;
run;

/** Industry-distress mean value weighted **/
rsubmit;
proc summary data=M8;
by date sic2 d_cat;
var payout wacc_old wacc sigma_saleq csr dsr / weight = size;
output out = ind1 mean = vw_payout vw_wacc_old vw_wacc vw_sigma_saleq vw_csr vw_dsr;
run;

  /** 3-year moving average **/
rsubmit;
proc sort data=ind1;
by d_cat sic2 date;
run;

rsubmit;
%let n = 36;
data payout;
  set ind1;
  by d_cat sic2;
  retain vw_payout_sum 0;
  if first.sic2 then do;
    count=0;
    vw_payout_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_payout);
  if count gt &n then vw_payout_sum=sum(vw_payout_sum,vw_payout,-last&n);
  else vw_payout_sum=sum(vw_payout_sum,vw_payout);
  if count ge &n then ma_vw_payout=vw_payout_sum/&n;
  else ma_vw_payout=.;
run;

%let n = 36;
data wacc_old;
  set ind1;
  by d_cat sic2;
  retain vw_wacc_old_sum 0;
  if first.sic2 then do;
    count=0;
    vw_wacc_old_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_wacc_old);
  if count gt &n then vw_wacc_old_sum=sum(vw_wacc_old_sum,vw_wacc_old,-last&n);
  else vw_wacc_old_sum=sum(vw_wacc_old_sum,vw_wacc_old);
  if count ge &n then ma_vw_wacc_old=vw_wacc_old_sum/&n;
  else ma_vw_wacc_old=.;
run;

%let n = 36;
data wacc;
  set ind1;
  by d_cat sic2;
  retain vw_wacc_sum 0;
  if first.sic2 then do;
    count=0;
    vw_wacc_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_wacc);
  if count gt &n then vw_wacc_sum=sum(vw_wacc_sum,vw_wacc,-last&n);
  else vw_wacc_sum=sum(vw_wacc_sum,vw_wacc);
  if count ge &n then ma_vw_wacc=vw_wacc_sum/&n;
  else ma_vw_wacc=.;
run;

%let n = 36;
data sigma_saleq;
  set ind1;
  by d_cat sic2;
  retain vw_sigma_saleq_sum 0;
  if first.sic2 then do;
    count=0;
    vw_sigma_saleq_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_sigma_saleq);
  if count gt &n then vw_sigma_saleq_sum=sum(vw_sigma_saleq_sum,vw_sigma_saleq,-last&n);
  else vw_sigma_saleq_sum=sum(vw_sigma_saleq_sum,vw_sigma_saleq);
  if count ge &n then ma_vw_sigma_saleq=vw_sigma_saleq_sum/&n;
  else ma_vw_sigma_saleq=.;
run;

%let n = 36;
data csr;
  set ind1;
  by d_cat sic2;
  retain vw_csr_sum 0;
  if first.sic2 then do;
    count=0;
    vw_csr_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_csr);
  if count gt &n then vw_csr_sum=sum(vw_csr_sum,vw_csr,-last&n);
  else vw_csr_sum=sum(vw_csr_sum,vw_csr);
  if count ge &n then ma_vw_csr=vw_csr_sum/&n;
  else ma_vw_csr=.;
run;

%let n = 36;
data dsr;
  set ind1;
  by d_cat sic2;
  retain vw_dsr_sum 0;
  if first.sic2 then do;
    count=0;
    vw_dsr_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_dsr);
  if count gt &n then vw_dsr_sum=sum(vw_dsr_sum,vw_dsr,-last&n);
  else vw_dsr_sum=sum(vw_dsr_sum,vw_dsr);
  if count ge &n then ma_vw_dsr=vw_dsr_sum/&n;
  else ma_vw_dsr=.;
run;

proc sql;
create table M9 as
select a.*,b.*
from M8 as a, payout as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M9a as
select a.*,b.*
from M9 as a, wacc_old as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M9b as
select a.*,b.*
from M9a as a, wacc as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M9c as
select a.*,b.*
from M9b as a, sigma_saleq as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M9d as
select a.*,b.*
from M9c as a, csr as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M9e as
select a.*,b.*
from M9d as a, dsr as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

rsubmit;
proc sort data=M9e;
by date sic2 d_cat;
run;

/** Industry-distress mean equal weighted **/
rsubmit;
proc summary data=M9e;
by date sic2 d_cat;
var payout wacc_old wacc sigma_saleq csr dsr;
output out = ind2 mean = ew_payout ew_wacc_old ew_wacc ew_sigma_saleq ew_csr ew_dsr;
run;

 /** 3-year moving average **/
rsubmit;
proc sort data=ind2;
by d_cat sic2 date;
run;

rsubmit;
%let n = 36;
data payout;
  set ind2;
  by d_cat sic2;
  retain ew_payout_sum 0;
  if first.sic2 then do;
    count=0;
    ew_payout_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_payout);
  if count gt &n then ew_payout_sum=sum(ew_payout_sum,ew_payout,-last&n);
  else ew_payout_sum=sum(ew_payout_sum,ew_payout);
  if count ge &n then ma_ew_payout=ew_payout_sum/&n;
  else ma_ew_payout=.;
run;

%let n = 36;
data wacc_old;
  set ind2;
  by d_cat sic2;
  retain ew_wacc_old_sum 0;
  if first.sic2 then do;
    count=0;
    ew_wacc_old_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_wacc_old);
  if count gt &n then ew_wacc_old_sum=sum(ew_wacc_old_sum,ew_wacc_old,-last&n);
  else ew_wacc_old_sum=sum(ew_wacc_old_sum,ew_wacc_old);
  if count ge &n then ma_ew_wacc_old=ew_wacc_old_sum/&n;
  else ma_ew_wacc_old=.;
run;

%let n = 36;
data wacc;
  set ind2;
  by d_cat sic2;
  retain ew_wacc_sum 0;
  if first.sic2 then do;
    count=0;
    ew_wacc_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_wacc);
  if count gt &n then ew_wacc_sum=sum(ew_wacc_sum,ew_wacc,-last&n);
  else ew_wacc_sum=sum(ew_wacc_sum,ew_wacc);
  if count ge &n then ma_ew_wacc=ew_wacc_sum/&n;
  else ma_ew_wacc=.;
run;

%let n = 36;
data sigma_saleq;
  set ind2;
  by d_cat sic2;
  retain ew_sigma_saleq_sum 0;
  if first.sic2 then do;
    count=0;
    ew_sigma_saleq_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_sigma_saleq);
  if count gt &n then ew_sigma_saleq_sum=sum(ew_sigma_saleq_sum,ew_sigma_saleq,-last&n);
  else ew_sigma_saleq_sum=sum(ew_sigma_saleq_sum,ew_sigma_saleq);
  if count ge &n then ma_ew_sigma_saleq=ew_sigma_saleq_sum/&n;
  else ma_ew_sigma_saleq=.;
run;

%let n = 36;
data csr;
  set ind2;
  by d_cat sic2;
  retain ew_csr_sum 0;
  if first.sic2 then do;
    count=0;
    ew_csr_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_csr);
  if count gt &n then ew_csr_sum=sum(ew_csr_sum,ew_csr,-last&n);
  else ew_csr_sum=sum(ew_csr_sum,ew_csr);
  if count ge &n then ma_ew_csr=ew_csr_sum/&n;
  else ma_ew_csr=.;
run;

%let n = 36;
data dsr;
  set ind2;
  by d_cat sic2;
  retain ew_dsr_sum 0;
  if first.sic2 then do;
    count=0;
    ew_dsr_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_dsr);
  if count gt &n then ew_dsr_sum=sum(ew_dsr_sum,ew_dsr,-last&n);
  else ew_dsr_sum=sum(ew_dsr_sum,ew_dsr);
  if count ge &n then ma_ew_dsr=ew_dsr_sum/&n;
  else ma_ew_dsr=.;
run;

proc sql;
create table M10 as
select a.*,b.*
from M9e as a, payout as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M10a as
select a.*,b.*
from M10 as a, wacc_old as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M10b as
select a.*,b.*
from M10a as a, wacc as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M10c as
select a.*,b.*
from M10b as a, sigma_saleq as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M10d as
select a.*,b.*
from M10c as a, csr as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

proc sql;
create table M10e as
select a.*,b.*
from M10d as a, dsr as b
where a.date=b.date
and a.sic2=b.sic2
and a.d_cat=b.d_cat;
run;

rsubmit;
proc sort data=M10e;
by permno date;
run;


/** Industry mean value weighted **/
rsubmit;
proc sort data=M10e;
by date sic2;
run;

rsubmit;
proc summary data=M10e;
by date sic2;
var payout wacc_old wacc sigma_saleq csr dsr / weight = size;
output out = ind3 mean = vw_payout vw_wacc_old vw_wacc vw_sigma_saleq vw_csr vw_dsr;
run;

  /** 3-year moving average **/
rsubmit;
proc sort data=ind3;
by sic2 date;
run;

rsubmit;
%let n = 36;
data payout;
  set ind3;
  by sic2;
  retain vw_payout_sum 0;
  if first.sic2 then do;
    count=0;
    vw_payout_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_payout);
  if count gt &n then vw_payout_sum=sum(vw_payout_sum,vw_payout,-last&n);
  else vw_payout_sum=sum(vw_payout_sum,vw_payout);
  if count ge &n then xma_vw_payout=vw_payout_sum/&n;
  else xma_vw_payout=.;
run;

%let n = 36;
data wacc_old;
  set ind3;
  by sic2;
  retain vw_wacc_old_sum 0;
  if first.sic2 then do;
    count=0;
    vw_wacc_old_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_wacc_old);
  if count gt &n then vw_wacc_old_sum=sum(vw_wacc_old_sum,vw_wacc_old,-last&n);
  else vw_wacc_old_sum=sum(vw_wacc_old_sum,vw_wacc_old);
  if count ge &n then xma_vw_wacc_old=vw_wacc_old_sum/&n;
  else xma_vw_wacc_old=.;
run;

%let n = 36;
data wacc;
  set ind3;
  by sic2;
  retain vw_wacc_sum 0;
  if first.sic2 then do;
    count=0;
    vw_wacc_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_wacc);
  if count gt &n then vw_wacc_sum=sum(vw_wacc_sum,vw_wacc,-last&n);
  else vw_wacc_sum=sum(vw_wacc_sum,vw_wacc);
  if count ge &n then xma_vw_wacc=vw_wacc_sum/&n;
  else xma_vw_wacc=.;
run;

%let n = 36;
data sigma_saleq;
  set ind3;
  by sic2;
  retain vw_sigma_saleq_sum 0;
  if first.sic2 then do;
    count=0;
    vw_sigma_saleq_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_sigma_saleq);
  if count gt &n then vw_sigma_saleq_sum=sum(vw_sigma_saleq_sum,vw_sigma_saleq,-last&n);
  else vw_sigma_saleq_sum=sum(vw_sigma_saleq_sum,vw_sigma_saleq);
  if count ge &n then xma_vw_sigma_saleq=vw_sigma_saleq_sum/&n;
  else xma_vw_sigma_saleq=.;
run;

%let n = 36;
data csr;
  set ind3;
  by sic2;
  retain vw_csr_sum 0;
  if first.sic2 then do;
    count=0;
    vw_csr_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_csr);
  if count gt &n then vw_csr_sum=sum(vw_csr_sum,vw_csr,-last&n);
  else vw_csr_sum=sum(vw_csr_sum,vw_csr);
  if count ge &n then xma_vw_csr=vw_csr_sum/&n;
  else xma_vw_csr=.;
run;

%let n = 36;
data dsr;
  set ind3;
  by sic2;
  retain vw_dsr_sum 0;
  if first.sic2 then do;
    count=0;
    vw_dsr_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_dsr);
  if count gt &n then vw_dsr_sum=sum(vw_dsr_sum,vw_dsr,-last&n);
  else vw_dsr_sum=sum(vw_dsr_sum,vw_dsr);
  if count ge &n then xma_vw_dsr=vw_dsr_sum/&n;
  else xma_vw_dsr=.;
run;

proc sql;
create table M11 as
select a.*,b.*
from M10e as a, payout as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M11a as
select a.*,b.*
from M11 as a, wacc_old as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M11b as
select a.*,b.*
from M11a as a, wacc as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M11c as
select a.*,b.*
from M11b as a, sigma_saleq as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M11d as
select a.*,b.*
from M11c as a, csr as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M11e as
select a.*,b.*
from M11d as a, dsr as b
where a.date=b.date
and a.sic2=b.sic2;
run;

rsubmit;
proc sort data=M11e;
by date sic2;
run;

/** Industry mean equal weighted **/
rsubmit;
proc summary data=M11e;
by date sic2;
var payout wacc_old wacc sigma_saleq csr dsr;
output out = ind4 mean = ew_payout ew_wacc_old ew_wacc ew_sigma_saleq ew_csr ew_dsr;
run;

 /** 3-year moving average **/
rsubmit;
proc sort data=ind4;
by sic2 date;
run;

rsubmit;
%let n = 36;
data payout;
  set ind4;
  by sic2;
  retain ew_payout_sum 0;
  if first.sic2 then do;
    count=0;
    ew_payout_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_payout);
  if count gt &n then ew_payout_sum=sum(ew_payout_sum,ew_payout,-last&n);
  else ew_payout_sum=sum(ew_payout_sum,ew_payout);
  if count ge &n then xma_ew_payout=ew_payout_sum/&n;
  else xma_ew_payout=.;
run;

%let n = 36;
data wacc_old;
  set ind4;
  by sic2;
  retain ew_wacc_old_sum 0;
  if first.sic2 then do;
    count=0;
    ew_wacc_old_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_wacc_old);
  if count gt &n then ew_wacc_old_sum=sum(ew_wacc_old_sum,ew_wacc_old,-last&n);
  else ew_wacc_old_sum=sum(ew_wacc_old_sum,ew_wacc_old);
  if count ge &n then xma_ew_wacc_old=ew_wacc_old_sum/&n;
  else xma_ew_wacc_old=.;
run;

%let n = 36;
data wacc;
  set ind4;
  by sic2;
  retain ew_wacc_sum 0;
  if first.sic2 then do;
    count=0;
    ew_wacc_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_wacc);
  if count gt &n then ew_wacc_sum=sum(ew_wacc_sum,ew_wacc,-last&n);
  else ew_wacc_sum=sum(ew_wacc_sum,ew_wacc);
  if count ge &n then xma_ew_wacc=ew_wacc_sum/&n;
  else xma_ew_wacc=.;
run;

%let n = 36;
data sigma_saleq;
  set ind4;
  by sic2;
  retain ew_sigma_saleq_sum 0;
  if first.sic2 then do;
    count=0;
    ew_sigma_saleq_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_sigma_saleq);
  if count gt &n then ew_sigma_saleq_sum=sum(ew_sigma_saleq_sum,ew_sigma_saleq,-last&n);
  else ew_sigma_saleq_sum=sum(ew_sigma_saleq_sum,ew_sigma_saleq);
  if count ge &n then xma_ew_sigma_saleq=ew_sigma_saleq_sum/&n;
  else xma_ew_sigma_saleq=.;
run;

%let n = 36;
data csr;
  set ind4;
  by sic2;
  retain ew_csr_sum 0;
  if first.sic2 then do;
    count=0;
    ew_csr_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_csr);
  if count gt &n then ew_csr_sum=sum(ew_csr_sum,ew_csr,-last&n);
  else ew_csr_sum=sum(ew_csr_sum,ew_csr);
  if count ge &n then xma_ew_csr=ew_csr_sum/&n;
  else xma_ew_csr=.;
run;

%let n = 36;
data dsr;
  set ind4;
  by sic2;
  retain ew_dsr_sum 0;
  if first.sic2 then do;
    count=0;
    ew_dsr_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_dsr);
  if count gt &n then ew_dsr_sum=sum(ew_dsr_sum,ew_dsr,-last&n);
  else ew_dsr_sum=sum(ew_dsr_sum,ew_dsr);
  if count ge &n then xma_ew_dsr=ew_dsr_sum/&n;
  else xma_ew_dsr=.;
run;

proc sql;
create table M12 as
select a.*,b.*
from M11e as a, payout as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M12a as
select a.*,b.*
from M12 as a, wacc_old as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M12b as
select a.*,b.*
from M12a as a, wacc as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M12c as
select a.*,b.*
from M12b as a, sigma_saleq as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M12d as
select a.*,b.*
from M12c as a, csr as b
where a.date=b.date
and a.sic2=b.sic2;
run;

proc sql;
create table M12e as
select a.*,b.*
from M12d as a, dsr as b
where a.date=b.date
and a.sic2=b.sic2;
run;

rsubmit;
proc sort data=M12e;
by permno date;
run;

/** Industry mean value weighted (just for market leverage)**/
rsubmit;
proc sort data=M12e;
by date sic2;
run;

rsubmit;
proc summary data=M12e;
by date sic2;
var mlvg / weight = size;
output out = ind5 mean = vw_mlvg;
run;

  /** 3-year moving average **/
rsubmit;
proc sort data=ind5;
by sic2 date;
run;

rsubmit;
%let n = 36;
data mlvg;
  set ind5;
  by sic2;
  retain vw_mlvg_sum 0;
  if first.sic2 then do;
    count=0;
    vw_mlvg_sum=0;
  end;
  count+1;
  last&n=lag&n(vw_mlvg);
  if count gt &n then vw_mlvg_sum=sum(vw_mlvg_sum,vw_mlvg,-last&n);
  else vw_mlvg_sum=sum(vw_mlvg_sum,vw_mlvg);
  if count ge &n then xma_vw_mlvg=vw_mlvg_sum/&n;
  else xma_vw_mlvg=.;
run;

proc sql;
create table M13 as
select a.*,b.*
from M12e as a, mlvg as b
where a.date=b.date
and a.sic2=b.sic2;
run;

/** Industry mean equal weighted (just for market leverage)**/
rsubmit;
proc sort data=M13;
by date sic2;
run;

rsubmit;
proc summary data=M13;
by date sic2;
var mlvg;
output out = ind6 mean = ew_mlvg;
run;

 /** 3-year moving average **/
rsubmit;
proc sort data=ind6;
by sic2 date;
run;

rsubmit;
%let n = 36;
data mlvg;
  set ind6;
  by sic2;
  retain ew_mlvg_sum 0;
  if first.sic2 then do;
    count=0;
    ew_mlvg_sum=0;
  end;
  count+1;
  last&n=lag&n(ew_mlvg);
  if count gt &n then ew_mlvg_sum=sum(ew_mlvg_sum,ew_mlvg,-last&n);
  else ew_mlvg_sum=sum(ew_mlvg_sum,ew_mlvg);
  if count ge &n then xma_ew_mlvg=ew_mlvg_sum/&n;
  else xma_ew_mlvg=.;
run;

proc sql;
create table M14 as
select a.*,b.*
from M13 as a, mlvg as b
where a.date=b.date
and a.sic2=b.sic2;
run;

rsubmit;
data model_inputs_all3;
set M14;
CHS_quintile=CHS_decile+1;
distress_cat=d_cat;
run;

rsubmit;
data model_inputs_3;
set model_inputs_all3;
keep permno date year month CHS_quintile distress_cat SIC2 sigma_saleq sigma_gmq rf re rb dlc dltt lvg mlvg wacc wacc_old 
     sale cogs gross_margin xsga capx csr dep dsr payout at size 
	 ma_vw_payout ma_vw_wacc_old ma_vw_wacc ma_vw_sigma_saleq ma_vw_csr ma_vw_dsr 
     ma_ew_payout ma_ew_wacc_old ma_ew_wacc ma_ew_sigma_saleq ma_ew_csr ma_ew_dsr 
     xma_vw_payout xma_vw_wacc_old xma_vw_wacc xma_vw_sigma_saleq xma_vw_csr xma_vw_dsr xma_vw_mlvg
     xma_ew_payout xma_ew_wacc_old xma_ew_wacc xma_ew_sigma_saleq xma_ew_csr xma_ew_dsr xma_ew_mlvg;
run;

rsubmit;
libname temp '/sastemp1/assafe1';
data temp.model_inputs_3;
set model_inputs_3;
run;

/**for the industry-distress means, leave values only when there are at least 10 firms **/

rsubmit;
proc sort data=model_inputs_all3;
by date sic2 d_cat;
run;

data model_inputs_all4;
set model_inputs_all3;
by date sic2 d_cat;
cnt+1; 
if first.d_cat then cnt=1; 
run; 

proc sort data=model_inputs_all4;
by date descending sic2 descending d_cat descending cnt;
run;

data model_inputs_all5;
set model_inputs_all4;
by date descending sic2 descending d_cat descending cnt;
if first.d_cat then do z=cnt;
end;
z+0;
run;

rsubmit;
data model_inputs_all3a;
set model_inputs_all5;
if z ge 10 then do;
xdma_vw_payout=ma_vw_payout;
xdma_vw_wacc_old=ma_vw_wacc_old;
xdma_vw_wacc=ma_vw_wacc;
xdma_vw_sigma_saleq=ma_vw_sigma_saleq;
xdma_vw_csr=ma_vw_csr;
xdma_vw_dsr=ma_vw_dsr;
xdma_ew_payout=ma_ew_payout;
xdma_ew_wacc_old=ma_ew_wacc_old;
xdma_ew_wacc=ma_ew_wacc;
xdma_ew_sigma_saleq=ma_ew_sigma_saleq;
xdma_ew_csr=ma_ew_csr;
xdma_ew_dsr=ma_ew_dsr;
end;
else do;
xdma_vw_payout=.;
xdma_vw_wacc_old=.;
xdma_vw_wacc=.;
xdma_vw_sigma_saleq=.;
xdma_vw_csr=.;
xdma_vw_dsr=.;
xdma_ew_payout=.;
xdma_ew_wacc_old=.;
xdma_ew_wacc=.;
xdma_ew_sigma_saleq=.;
xdma_ew_csr=.;
xdma_ew_dsr=.;
end;
run;

rsubmit;
data model_inputs_3a;
set model_inputs_all3a;
keep permno date year month CHS_quintile distress_cat SIC2 sigma_saleq sigma_gmq rf re rb dlc dltt lvg mlvg wacc wacc_old 
     sale cogs gross_margin xsga capx csr dep dsr payout at size 
	 xdma_vw_payout xdma_vw_wacc_old xdma_vw_wacc xdma_vw_sigma_saleq xdma_vw_csr xdma_vw_dsr 
     xdma_ew_payout xdma_ew_wacc_old xdma_ew_wacc xdma_ew_sigma_saleq xdma_ew_csr xdma_ew_dsr 
     xma_vw_payout xma_vw_wacc_old xma_vw_wacc xma_vw_sigma_saleq xma_vw_csr xma_vw_dsr xma_vw_mlvg
     xma_ew_payout xma_ew_wacc_old xma_ew_wacc xma_ew_sigma_saleq xma_ew_csr xma_ew_dsr xma_ew_mlvg;
run;

rsubmit;
proc sort data=model_inputs_3a;
by permno date;
run;

rsubmit;
libname temp '/sastemp1/assafe1';
data temp.model_inputs_3a;
set model_inputs_3a;
run;



