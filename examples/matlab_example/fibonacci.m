function a = fibonacci(n)
maxNumCompThreads (1)
% FIBONACCI Calculate the fibonacci value of n.
% When complied as standalone function,
% arguments are always passed as strings, not nums ...
if (isstr(n))
  n = str2num(n);
end;
if (length(n)~=1) || (fix(n) ~= n) || (n < 0)
  error(['MATLAB:factorial:NNotPositiveInteger', ...
        'N must be a positive integer.']);
end
first = 0;second = 1;
for i=1:n-1
    next = first+second;
    first=second;
    second=next;
end
% When called from a compiled application, display result
if (isdeployed)
  disp(sprintf('Fibonacci %d -> %d' , n,first))
end
% Also return the result, so that the function remains usable
% from other Matlab scripts.
a=first;

filename=sprintf('fibonacci%03i.txt',n);
fid=fopen(filename,'w');
fprintf(fid,'Write to file: Fibonacci %d -> %d' , n,a);
fclose(fid);

