%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% code of function leverage1.m

function f=leverage1(z)
    global xsga0 RF g Volatility Earnings DSR CSR gmratio D5 E5 xd a b c INDLEV t 
    
    c=z;
    b2=0.5-g/Volatility^2-sqrt((g/Volatility^2-0.5)^2+2*RF/Volatility^2);
    a=(t*DSR-CSR)/gmratio+(1-t);
    b=(1-t)*(c+xsga0);
    xd=b2/(b2-1)*b*(RF-g)/a/RF;

    E5=a*Earnings/(RF-g)-b/RF+(Earnings/xd)^b2*(b/RF-a*xd/(RF-g));
    D5=c/RF+(Earnings/xd)^b2*(a*xd/(RF-g)-c/RF);

    f=D5/(E5+D5)-INDLEV;
    if xd>Earnings 
        f=1000; 
    end
end