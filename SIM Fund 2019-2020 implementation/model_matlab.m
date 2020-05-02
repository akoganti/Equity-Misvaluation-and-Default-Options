function valuation = model_matlab(dlc,dltt,sales,xsga,sigma,rf,rb,gm,RA,csr,dsr,indlev)

    global xsga0 RF g Volatility Earnings DSR CSR gmratio D5 E5 xd a b c INDLEV t
    valuation = -3333
    
    N=10;
    t=0.35;

    Volatility=sigma;
    RF=rf;
    CSR=csr;
    DSR=dsr;
    INDLEV=indlev;

    if RA<RF 
        RA=RF; 
    end
    if xsga<0 
        xsga=0; 
    end
    Earnings0=gm;
    if (sales > 0) && (gm >0)  
        gmratio=gm/sales;
        if CSR>gmratio*(1-t) 
            CSR=gmratio*(1-t); 
        end
        mu=CSR*RA/((1-t)*gmratio+t*DSR); 
        xsga0=xsga;
        g=RF-RA+mu;
        if RF-g>0 
            T=5;
            eta=0.15;
            for ii=1:1:T
            xsga(ii)=xsga0*exp(0.00*ii);
            end
            D=zeros(T,1);
            int=zeros(T,1);
            D(5)=dltt+D(5);
            D(1)=dlc+D(1);
            % interest on long-term debt
            for jjj=1:1:5;
            int(jjj)=int(jjj)+rb*dltt;
            end
            dt=1/N;
            % set up the grid
            % j=0;
            % risk neutral probability
            dx=sqrt(dt)*Volatility;
            alfa=g-0.5*Volatility^2;
            % boundaries on the log of cashflows
            xlow=-5; xhigh=10;
            %number of steps
            M=floor(T/dt);
            D1=zeros(M,1);
            int1=zeros(M,1);
            for j=2:1:M-1
                if floor(j*dt)~=floor((j-1)*dt)
                    i=floor(j*dt);
                    D1(j)=D(i);
                    int1(j)=int(i);
                end
                   i=floor(j*dt);
                   xsga1(j)=xsga(i+1); % multiply by dt later
            end
            D1(M-1)=D(5);
            % setting up the values at time T
            for x=xlow:dx:xhigh;
                Earnings=exp(x);
                np=round((x-xlow)/dx+1);   
                %    
                b2=0.5-g/Volatility^2-sqrt((g/Volatility^2-0.5)^2+2*RF/Volatility^2);
                OPTIONS = optimset('Display','off');
                x0=Earnings*0.05;
                [y,fval,exitflag,output] = fzero('leverage1',x0,OPTIONS);
                if exitflag==1 
                    leverage1(y); 
                    e(np)=E5+D5; 
                end
                if exitflag~=1 
                    if xsga0==0 
                        e(np)=Earnings*(1-t+(t*DSR-CSR)/gmratio)/(RF-g);
                    else
                        b2=0.5-g/Volatility^2-sqrt((g/Volatility^2-0.5)^2+2*RF/Volatility^2);
                        a=(t*DSR-CSR)/gmratio+(1-t);
                        b=(1-t)*xsga0;
                        xd=b2/(b2-1)*b*(RF-g)/a/RF;

                        if Earnings>xd
                            e(np)=a*Earnings/(RF-g)-b/RF+(Earnings/xd)^b2*(b/RF-a*xd/(RF-g));
                        else
                            e(np)=0;
                        end
                    end
                end
                if e(np)<0 
                    e(np)=0; 
                end
            end

            NP=np;

            % rolling valuations back
            e1(1)=0;
            e1(NP)=e(NP);

            etresh=zeros(1,M);

            for k=M-1:-1:1
                for x=xlow+dx:dx:xhigh-dx;
                    Earnings=exp(x);
                    np=round((x-xlow)/dx+1);    
                    cf=(Earnings*(1-t+(t*DSR-CSR)/gmratio)-(1-t)*xsga1(k))*dt-(1-t)*int1(k);
                    if cf<0 
                        cf=cf*(1+eta); 
                    end
                    cf=cf-D1(k);
                    e1(np)=0.5*(1-RF*dt)*(e(np+1)*(1+alfa*sqrt(dt)/Volatility)+e(np-1)*(1-alfa*sqrt(dt)/Volatility))+cf;  
                    if e1(np)<0 
                        e1(np)=0; 
                    end
                end
                e=e1;
            end
            % computing equity value at time zero
            n1=round((log(Earnings0)-xlow)/dx+1); 
            sss=size(e);
            sss1=sss(2);
            if n1>1 && imag(n1)==0 && n1<sss1 
                valuation=e(n1); 
            end
            % clear e e1;
        end    
    end    
end


