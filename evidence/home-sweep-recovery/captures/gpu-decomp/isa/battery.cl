#pragma OPENCL EXTENSION cl_khr_fp16 : enable
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
// Each kernel isolates one math type so the emitted VALU opcode is the finding.
kernel void fp32_fma(global float* o, global const float* a, global const float* b){
  int i=get_global_id(0); float acc=0.f;
  for(int k=0;k<64;k++) acc=fma(a[i*64+k],b[i*64+k],acc);
  o[i]=acc;
}
kernel void fp16_fma(global half* o, global const half* a, global const half* b){
  int i=get_global_id(0); half acc=0.h;
  for(int k=0;k<64;k++) acc=fma(a[i*64+k],b[i*64+k],acc);
  o[i]=acc;
}
kernel void fp16x2_fma(global half2* o, global const half2* a, global const half2* b){
  int i=get_global_id(0); half2 acc=(half2)(0.h,0.h);
  for(int k=0;k<64;k++) acc=fma(a[i*64+k],b[i*64+k],acc);
  o[i]=acc;
}
kernel void fp16_acc_fp32(global float* o, global const half* a, global const half* b){
  int i=get_global_id(0); float acc=0.f;
  for(int k=0;k<64;k++) acc=fma((float)a[i*64+k],(float)b[i*64+k],acc);
  o[i]=acc;
}
kernel void int8_dot4(global int* o, global const char4* a, global const char4* b){
  int i=get_global_id(0); int acc=0;
  for(int k=0;k<64;k++){ char4 x=a[i*64+k], y=b[i*64+k];
    acc += (int)x.s0*(int)y.s0 + (int)x.s1*(int)y.s1 + (int)x.s2*(int)y.s2 + (int)x.s3*(int)y.s3; }
  o[i]=acc;
}
kernel void int16x2_mad(global int2* o, global const short2* a, global const short2* b){
  int i=get_global_id(0); int2 acc=(int2)(0,0);
  for(int k=0;k<64;k++){ short2 x=a[i*64+k], y=b[i*64+k];
    acc += convert_int2(x)*convert_int2(y); }
  o[i]=acc;
}
kernel void fp64_fma(global double* o, global const double* a, global const double* b){
  int i=get_global_id(0); double acc=0.0;
  for(int k=0;k<64;k++) acc=fma(a[i*64+k],b[i*64+k],acc);
  o[i]=acc;
}
