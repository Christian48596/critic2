// Copyright (c) 2017 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
// Ángel Martín Pendás <angel@fluor.quimica.uniovi.es> and Víctor Luaña
// <victor@fluor.quimica.uniovi.es>.
//
// critic2 is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// critic2 is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include "shapes.h"
#include "settings.h"
#include <cmath>
#include <cstring>
#include <map>

using namespace std;

// global variables
const int nmaxsph = 4;
GLuint sphereVAO[nmaxsph];
GLuint sphereVBO;
GLuint sphereEBO[nmaxsph];
const GLuint spherenve[nmaxsph]    = {     12,  42, 162,  642};
const GLuint spherenel[nmaxsph]    = {     20,  80, 320, 1280};
const GLuint sphereneladd[nmaxsph+1] = {0, 20, 100, 420, 1700};
const int nmaxcyl = 1;
GLuint cylVAO[nmaxcyl];
GLuint cylVBO;
GLuint cylEBO[nmaxcyl];
const GLuint cylnve[nmaxcyl]    = {     14};
const GLuint cylnel[nmaxcyl]    = {     24};
const GLuint cylneladd[nmaxcyl+1] = {0, 24};

// Some constants
static float tau = (1.0 + sqrt(5))/2.0;
static float rad0 = sqrt(3 - tau);
static float xico = (tau-1)/rad0;
static float zico = 1/rad0;

// icosahedron  vertices
static GLfloat *icov;
static const GLfloat icov0[] = {
  -xico,   0.0,  zico,  -xico,   0.0,  zico,
   xico,   0.0,  zico,   xico,   0.0,  zico,
  -xico,   0.0, -zico,  -xico,   0.0, -zico,
   xico,   0.0, -zico,   xico,   0.0, -zico,
    0.0,  zico,  xico,    0.0,  zico,  xico,
    0.0,  zico, -xico,    0.0,  zico, -xico,
    0.0, -zico,  xico,    0.0, -zico,  xico,
    0.0, -zico, -xico,    0.0, -zico, -xico,
   zico,  xico,   0.0,   zico,  xico,   0.0,
  -zico,  xico,   0.0,  -zico,  xico,   0.0,
   zico, -xico,   0.0,   zico, -xico,   0.0,
  -zico, -xico,   0.0,  -zico, -xico,   0.0,
};

// icosehedron faces
static GLuint *icoi;
static GLuint icoi0[] = {
  1,  4,  0,
  4,  9,  0,
  4,  5,  9,
  8,  5,  4,
  1,  8,  4,
  1, 10,  8,
  10, 3,  8,
  8,  3,  5,
  3,  2,  5,
  3,  7,  2,
  3, 10,  7,
  10, 6,  7,
  6, 11,  7,
  6,  0, 11,
  6,  1,  0,
  10, 1,  6,
  11, 0,  9,
  2, 11,  9,
  5,  2,  9,
  11, 2,  7
};

// hexagonal prism vertices
static GLfloat *cylv;
static GLfloat cylv0[] = {
  -0.86602540,  0.50000000,  0.00000000,  -0.86602540,  0.50000000,  0.00000000,
  -0.86602540, -0.50000000,  0.00000000,  -0.86602540, -0.50000000,  0.00000000,
  -0.00000000, -1.00000000,  0.00000000,  -0.00000000, -1.00000000,  0.00000000,
   0.86602540, -0.50000000,  0.00000000,   0.86602540, -0.50000000,  0.00000000,
   0.86602540,  0.50000000,  0.00000000,   0.86602540,  0.50000000,  0.00000000,
   0.00000000,  1.00000000,  0.00000000,   0.00000000,  1.00000000,  0.00000000,
  -0.86602540,  0.50000000,  1.00000000,  -0.86602540,  0.50000000,  1.00000000,
  -0.86602540, -0.50000000,  1.00000000,  -0.86602540, -0.50000000,  1.00000000,
  -0.00000000, -1.00000000,  1.00000000,  -0.00000000, -1.00000000,  1.00000000,
   0.86602540, -0.50000000,  1.00000000,   0.86602540, -0.50000000,  1.00000000,
   0.86602540,  0.50000000,  1.00000000,   0.86602540,  0.50000000,  1.00000000,
   0.00000000,  1.00000000,  1.00000000,   0.00000000,  1.00000000,  1.00000000,
   0.00000000,  0.00000000,  0.00000000,   0.00000000,  0.00000000,  0.00000000,
   0.00000000,  0.00000000,  1.00000000,   0.00000000,  0.00000000,  1.00000000,
};

// hexagonal prism faces
static GLuint *cyli;
static GLuint cyli0[] = {
  12,  0,  1,
  13,  6,  7,
   0,  1,  6,
   7,  6,  1,
  12,  1,  2,
  13,  7,  8,
   1,  2,  7,
   8,  7,  2,
  12,  2,  3,
  13,  8,  9,
   2,  3,  8,
   9,  8,  3,
  12,  3,  4,
  13,  9, 10,
   3,  4,  9,
  10,  9,  4,
  12,  4,  5,
  13, 10, 11,
   4,  5, 10,
  11, 10,  5,
  12,  5,  0,
  13, 11,  6,
   5,  0, 11,
   6, 11,  0
};

// create the buffers for the sphere and cylinder objects
void CreateAndFillBuffers(){
  // allocate space for the icospheres and copy the icosahedron as the first icosphere
  icov = new GLfloat [6*spherenve[nmaxsph-1]];
  icoi = new GLuint [3*sphereneladd[nmaxsph]];
  memcpy(icov,icov0,sizeof(icov0));
  memcpy(icoi,icoi0,sizeof(icoi0));

  // recursive subdivision for the other icospheres
  for (int i = 1; i < nmaxsph; i++){
    map<pair<int,int>,int> edgev = {};

    int n = spherenve[i-1] - 1;
    int nface = sphereneladd[i]-1;
    for (int j = sphereneladd[i-1]; j < sphereneladd[i]; j++){
      int k1 = icoi[3*j+0];
      int k2 = icoi[3*j+1];
      int k3 = icoi[3*j+2];
      int nk1, nk2, nk3;

      // create the new vertices
      if (edgev[make_pair(k1,k2)]){
        nk1 = edgev[make_pair(k1,k2)];
      } else {
        edgev[make_pair(k1,k2)] = edgev[make_pair(k2,k1)] = nk1 = ++n;
        icov[6*n+0] = icov[6*n+3] = 0.5f * (icov[6*k1+0] + icov[6*k2+0]);
        icov[6*n+1] = icov[6*n+4] = 0.5f * (icov[6*k1+1] + icov[6*k2+1]);
        icov[6*n+2] = icov[6*n+5] = 0.5f * (icov[6*k1+2] + icov[6*k2+2]);
      }
      if (edgev[make_pair(k1,k3)]){
        nk2 = edgev[make_pair(k1,k3)];
      } else {
        edgev[make_pair(k1,k3)] = edgev[make_pair(k3,k1)] = nk2 = ++n;
        icov[6*n+0] = icov[6*n+3] = 0.5f * (icov[6*k1+0] + icov[6*k3+0]);
        icov[6*n+1] = icov[6*n+4] = 0.5f * (icov[6*k1+1] + icov[6*k3+1]);
        icov[6*n+2] = icov[6*n+5] = 0.5f * (icov[6*k1+2] + icov[6*k3+2]);
      }
      if (edgev[make_pair(k2,k3)]){
        nk3 = edgev[make_pair(k2,k3)];
      } else {
        edgev[make_pair(k2,k3)] = edgev[make_pair(k3,k2)] = nk3 = ++n;
        icov[6*n+0] = icov[6*n+3] = 0.5f * (icov[6*k2+0] + icov[6*k3+0]);
        icov[6*n+1] = icov[6*n+4] = 0.5f * (icov[6*k2+1] + icov[6*k3+1]);
        icov[6*n+2] = icov[6*n+5] = 0.5f * (icov[6*k2+2] + icov[6*k3+2]);
      }

      // create the new faces
      nface++;
      icoi[3*nface+0] = k1;  icoi[3*nface+1] = nk1; icoi[3*nface+2] = nk2; 
      nface++;
      icoi[3*nface+0] = nk1; icoi[3*nface+1] = nk3; icoi[3*nface+2] = nk2; 
      nface++;
      icoi[3*nface+0] = nk1; icoi[3*nface+1] = k2;  icoi[3*nface+2] = nk3; 
      nface++;
      icoi[3*nface+0] = nk2; icoi[3*nface+1] = nk3; icoi[3*nface+2] = k3; 
    }

    // normalize the vertices
    for (int j = spherenve[i-1]; j < spherenve[i]; j++){
      float anorm = sqrtf(icov[6*j+0]*icov[6*j+0]+icov[6*j+1]*icov[6*j+1]+icov[6*j+2]*icov[6*j+2]);
      icov[6*j+0] = icov[6*j+3] = icov[6*j+0] / anorm;
      icov[6*j+1] = icov[6*j+4] = icov[6*j+1] / anorm;
      icov[6*j+2] = icov[6*j+5] = icov[6*j+2] / anorm;
    }
  }

  // build the buffers for the spheres
  glGenVertexArrays(nmaxsph, sphereVAO);
  glGenBuffers(1, &sphereVBO);
  glGenBuffers(nmaxsph, sphereEBO);

  glBindBuffer(GL_ARRAY_BUFFER, sphereVBO);
  glBufferData(GL_ARRAY_BUFFER, 6 * spherenve[nmaxsph-1] * sizeof(GLfloat), icov, GL_STATIC_DRAW);

  for (int i=0;i<nmaxsph;i++){
    glBindVertexArray(sphereVAO[i]);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sphereEBO[i]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 3 * spherenel[i] * sizeof(GLuint), &(icoi[3*sphereneladd[i]]), GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (void*)(3 * sizeof(GLfloat)));
    glEnableVertexAttribArray(1);
  }

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

  // allocate space for the icospheres and copy the icosahedron as the first icosphere
  cylv = new GLfloat [6*cylnve[nmaxcyl-1]];
  cyli = new GLuint [3*cylneladd[nmaxcyl]];
  memcpy(cylv,cylv0,sizeof(cylv0));
  memcpy(cyli,cyli0,sizeof(cyli0));

  // xxxx //

  // build the buffers for the cylinders
  glGenVertexArrays(nmaxcyl, cylVAO);
  glGenBuffers(1, &cylVBO);
  glGenBuffers(nmaxcyl, cylEBO);

  glBindBuffer(GL_ARRAY_BUFFER, cylVBO);
  glBufferData(GL_ARRAY_BUFFER, 6 * cylnve[nmaxcyl-1] * sizeof(GLfloat), cylv, GL_STATIC_DRAW);

  for (int i=0;i<nmaxcyl;i++){
    glBindVertexArray(cylVAO[i]);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cylEBO[i]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 3 * cylnel[i] * sizeof(GLuint), &(icoi[3*cylneladd[i]]), GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (void*)(3 * sizeof(GLfloat)));
    glEnableVertexAttribArray(1);
  }

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
  
}

// delete the buffers for the sphere and cylinder objects
void DeleteBuffers(){
  glDeleteVertexArrays(nmaxsph, sphereVAO);
  glDeleteBuffers(1, &sphereVBO);
  glDeleteBuffers(nmaxsph, sphereEBO);
  glDeleteVertexArrays(nmaxcyl, cylVAO);
  glDeleteBuffers(1, &cylVBO);
  glDeleteBuffers(nmaxcyl, cylEBO);
  delete icoi;
  delete icov;
}
