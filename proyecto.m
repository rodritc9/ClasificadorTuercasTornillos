% Título: Clasificador de piezas
% Autor: Rodrigo Torres
% Año de creación: 2016
% Carrera: Ingeniería en Mecatrónica
% Cátedra: Inteligencia Artificial I
% Facultad de Ingeniería - Universidad Nacional de Cuyo

%=========================================================================

clear all
clc
close all

%FORMAMOS BASE DE CONOCIMIENTO

srcFiles=dir('C:\Users\Rodrigo Torres\Pictures\base de conocimiento\*.JPG');
 
for k=1:length(srcFiles)
    
file=strcat('C:\Users\Rodrigo Torres\Pictures\base de conocimiento\',srcFiles(k).name);

   
%leo el archivo de imagen a clasificar
foto1 = imread(file);

%se aplica filtro de brillo para eliminar sombras posibles
foto1=2*foto1;

%pasa la imagen a binario (0 o 1) (blanco o negro) calculando previamente
%un valor umbral normalizado para hacer un mejor pasaje a binario
umb=graythresh(foto1);

binaria=im2bw(foto1,umb);

%invierto la binaria 
binaria=not(binaria);

%elimino pequeños ruidos(pixels aislados)
binaria=bwareaopen(binaria,100);

%aplico filtro de dilatacion
se=strel('square',20);
binaria=imdilate(binaria,se);

%elimino los blancos aislados de mi figura que hagan ruido en el analisis(pixels aislados)
binaria=bwareaopen(binaria,100);

%calculo filas y columnas de mi foto
A=size(binaria);
filas=A(1);
columnas=A(2);

%cuento elementos de la foto y los etiqueta
[L NE]=bwlabel(binaria);


%encuentro propiedades de las imagenes detectadas(dimensiones, area y centroide) donde
%propiedades es una variable tipo struct
propiedades=regionprops(L);

subplot(2,4,k)
imshow(binaria);

%encierro en un rectangulo 
hold on
for n=1:length(propiedades)
rectangle('position',propiedades(n).BoundingBox,'EdgeColor','g','LineWidth',2);
A(n)=propiedades(n).Area;
end

%determino las propiedades del centroide de la figura de mayor area
Q=max(A);
[z]=find(A(1,:)==Q);

x=propiedades(z).Centroid(1); %X VA A ESTAR EN MIS COLUMNAS
y=propiedades(z).Centroid(2); %Y VA A ESTAR EN MIS FILAS
plot(x,y,'+') %se representa el controide en cada figura con un +
hold off

x=floor(x); %columna del centroide
y=floor(y); %fila del centroide  Centroide(y,x)

%mido la distancia desde el controide hasta el primer blanco (parametro representativo de cada figura)
dy=0;
for(i=y:filas)
    c=binaria(i,x);
    dy=dy+1;
    if(c==1)
        break;
    end
end

dx=0;
for(i=x:columnas)
    c=binaria(y,i);
    dx=dx+1;
    if(c==1)
        break;
    end
end

d=dy+dx;

%artilugio matematico que me permita trabajar en un rango acotado de
%valores
if(d>50)
    d=d/(floor(d/10));
end

%guardo los valores representativos de cada imagen en un vector
D(k)=d;

end

%aplico k-means para formar mi base de datos

c1=0;
c2=10;

for (n=1:10)
    
    %agrupo
    for(m=1:length(D))
        
        distancia1=abs(D(m)-c1); %al centroide de clase arandela
        distancia2=abs(D(m)-c2); %al centroide de clase tornillo
    
    if(distancia1<distancia2)
        Clusters(m)=1;
    else
        Clusters(m)=2;
    end
    end
    
    [cc1]=find(Clusters(1,:)==1);

    [cc2]=find(Clusters(1,:)==2);
    
    %saco los nuevos centros
    suma1=0;
    for(m=1:length(cc1))
        suma1=suma1+D(cc1(m));    
    end
    c1=(c1+suma1)/(1+length(cc1));
    
    suma2=0;
    for(m=1:length(cc2))
        suma2=suma2+D(cc2(m));    
    end
    c2=(c2+suma2)/(1+length(cc2));
end   

%A PARTIR DE ACA CON Knn EMPEZAMOS A CLASIFICAR LAS NUEVAS FIGURAS EN
%CLAVOS O ARANDELAS

analisis= input('presione 1 si desea clasificar una imagen, o 0 para salir: ');
k=0;
%figure(2)
while(analisis==1)
    k=k+1;
nueva_foto= input('ingrese direccion de la foto');
    
%leo el archivo de imagen a clasificar
foto_nueva = imread(nueva_foto);

foto_nueva=2*foto_nueva;

A=size(foto_nueva);
filas=A(1);
columnas=A(2);

%pasa la imagen a binario (0 o 1) (blanco o negro) calculando previamente
%un valor umbral normalizado para hacer un mejor pasaje a binario
umb=graythresh(foto_nueva);

foto_nueva_binaria=im2bw(foto_nueva,umb);

%invierto la binaria 
foto_nueva_binaria=not(foto_nueva_binaria);

%elimino pequeños ruidos(pixels aislados)
foto_nueva_binaria=bwareaopen(foto_nueva_binaria,100);

%aplico filtro de dilatacion
se=strel('square',20);
foto_nueva_binaria=imdilate(foto_nueva_binaria,se);

%elimino los blancos aislados(pixels aislados)
foto_nueva_binaria=bwareaopen(foto_nueva_binaria,100);

%cuento elementos de la foto y los etiqueta
[H NE]=bwlabel(foto_nueva_binaria);


%encuentro propiedades de las imagenes detectadas(dimensiones, area y centroide centroide) donde
%propiedades es una variable tipo struct
propiedad=regionprops(H);

if(k==1)
figure(2)
end
subplot(4,4,k)
imshow(foto_nueva_binaria);

%encierro en un rectangulo 
hold on
for n=1:length(propiedad)
rectangle('position',propiedad(n).BoundingBox,'EdgeColor','g','LineWidth',2);
A(n)=propiedad(n).Area;
end

%determino las propiedades del centroide de la figura de mayor area
Q=max(A);
[z]=find(A(1,:)==Q);

x=propiedad(z).Centroid(1); %X VA A ESTAR EN MIS COLUMNAS
y=propiedad(z).Centroid(2); %Y VA A ESTAR EN MIS FILAS
plot(x,y,'+')
hold off

x=floor(x); %columna del centroide
y=floor(y); %fila del centroide  Centroide(y,x)

d=0;
dy=0;
for(i=y:filas)
    c=foto_nueva_binaria(i,x);
    dy=dy+1;
    if(c==1)
        break;
    end
end

dx=0;
for(i=x:columnas)
    c=foto_nueva_binaria(y,i);
    dx=dx+1;
    if(c==1)
        break;
    end
end

d=dy+dx;

if(d>50)
    d=d/(floor(d/10));
end


for i=1:length(D)
    diferencia(i)=abs(d-D(i));
end

Cluster1=0;
Cluster2=0;

diferencia;

for (K=1:3)
    
    Q=min(diferencia);
    [l]=find(diferencia(1,:)==Q);
    l=min(l);
    if (Clusters(l)==1)
        Cluster1=Cluster1+1;
    else
        Cluster2=Cluster2+1;
    end
    
    diferencia(l)=12000;
end

if(Cluster1>Cluster2)
    title('es un clavo');
    display('es un clavo');
else
    title('es una arandela');
    display('es una arandela');
end

if(k==16)
    break;
end

analisis= input('presione 1 si desea clasificar otra imagen, o 0 para salir: ');

end
