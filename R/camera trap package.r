# Estimate population size using camera trapping data
#============================================================================================================================

# plot camera trapping results
#############################################################################################################################
#' plot camera trapping results, showing the locations of the cameras and the number of pictures
#'
#' @description This function shows the locations of each camera in a camera trap grid, the number of pictures
#'  taken by each camera for one species.
#'
#' @author Xinhai Li (Xinhai_li_edu@126.com)
#'
#' @param x A data.frame with column names "Lon", "Lat", "Group_size", "Date", "Time"
#'
#' @param circle.size A value controls the size the circles. The defualt value is 0.2.
#'
#' @param point.scatter A value controls the distance between every point (representing a picture)
#'  at the same camera. The defualt value is 5.
#'
#' @return
#'
#' @examples
#'
#'  attach(trapresult)
#'  plotCamtrap(trapresult)
#'  plotCamtrap(trapresult, circle.size = .5, point.scatter = 10)
#'
#' @export

plotCamtrap = function(x, circle.size=.2, point.scatter=5){
  sum = aggregate(x$Group_size, by = list(x$Lat, x$Lon), sum)
  colnames(sum) = c('Lat','Lon','Count')
  plot(x$Lon, x$Lat, pch=1, cex = 1, xlab='Longitude', ylab='Latitude')
  points(sum$Lon, sum$Lat, pch = 16,
         col = colorRampPalette(c("grey90", "grey50"))(length(sum$Count))[round(rank(sum$Count))], cex=sum$Count*circle.size)
  X = x[x$Group_size > 0, ]
  dates = as.numeric(as.Date(X$Date, origin = "1900-01-01"))
  points(jitter(X$Lon, factor=point.scatter), jitter(X$Lat, factor=point.scatter),
         pch = 1, cex=1, col = colorRampPalette(c("red", "yellow", "green"))(length(dates))[round(rank(dates))])
  # points(x$Lon, x$Lat, cex=.5)
}
#############################################################################################################################






# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
#' plot the daily rhythm of species' activity
#'
#' @description This function plots the curves of probability density of animal activity (density of picture time) in 24 hours
#'
#' @author Xinhai Li (Xinhai_li_edu@126.com)
#'
#' @param x A data.frame with column names "Lon", "Lat", "Group_size", "Date", "Time"
#'
#' @return
#'
#' @examples
#'
#'  attach(trapresult)
#'  dailyRhythm(trapresult)
#'
#' @export

dailyRhythm = function(x){
  times <- x$Time
  baseline = as.numeric(strptime('0:0:0', "%H:%M:%S"))
  times <- (as.numeric(strptime(times, "%H:%M:%S")) - baseline) / 3600
  plot(density(times, bw=0.3), xlim=c(0,24), xlab='Hour', ylab = 'Activity', main='')
  lines(density(times, bw=2),lwd = 2)
}
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA




# CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
#' Convertr longitude & latitude from geographic to projected coordinate system
#'
#' @description This function converts longitude & latitude from geographic to projected coordinate system.
#'  Users can specify their coordinate reference systems, or leave them as default. The default setting will
#'  using "WGS83" as geographic coordinates system and "UTM" as the projection coordinates system. The "zone"
#'  for UTM projection system will be determined using the centriod of points (longitude & latitude).
#'
#' @author Huidong Tian (tienhuitung@gmail.com)
#'
#' @param data data.frame with column names "Lon" & "Lat"
#'
#' @param geo geographic coordinate system, e.g. "+proj=longlat +datum=WGS84"
#'
#' @param proj projection coordinate system, e.g. "+proj=utm +zone=30 ellps=WGS84"
#'
#' @return Return a data.frame with column names "Lon" & "Lat". The unit of "Lon" & "Lat" is meter now.
#'
#' @examples
#'
#'  camera.geo <- data.frame(Lon = rnorm(10, 120, 10), Lat = rnorm(10, 30, 5))
#'  par(mfrow = c(1, 2))
#'  with(camera.geo, plot(Lon, Lat, xlab = "Longitude", ylab = "Latitude", main = "Geographic coordinate system"))
#'
#'  camera.proj <- geo2proj(camera.geo)
#'  with(camera.proj, plot(Lon, Lat, xlab = "Longitude", ylab = "Latitude", main = "Geographic coordinate system"))
#' @import sp
#' @export
#'

geo2proj <- function(data, geo = NULL, proj = NULL) {

  if (!requireNamespace("sp", quietly = TRUE)) {
    stop("Package 'sp' needed for this function to work. Please install it.",
         call. = FALSE)
  }

  if (max(abs(data$Lat)) > 90 | max(abs(data$Lon)) >180) {
    stop("The longitude and/or latitude is not in geographic coordinate system!")
  }


  coordinates(data) <- c("Lon", "Lat")
  ## Assign geographic CRS
  if (!is.null(geo)) {
    proj4string(data) <- CRS(geo)
  } else {
    proj4string(data) <- CRS("+proj=longlat +datum=WGS84")
  }
  ## Convert to projection CRS
  if (!is.null(proj)) {
    res <- spTransform(data, CRS(proj))
  } else {
    zone <- floor((mean(data$Lon) + 180) /6)  %% 60 +1 #
    res <- spTransform(data, CRS(sprintf("+proj=utm +zone=%s ellps=WGS84", zone)))
  }
  return(as.data.frame(res))
}
# CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

# library(sp)
# trapresult = geo2proj(trapresult) # converts longitude & latitude from geographic coordinate system to equal area UTM system









# simulate camera trapping processes
#SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
#' Simulate animal movement within the range of the camera trap grid and obtain the pseudo camera trap result
#'
#' @description Correlated random walk of the target animal is simulated within the range of camera trap grid,
#'  using the distributions of step length, turning angles, and size of home range from footprint chain data.
#'  The simulated movement of the default 1-10 individuals generate pseudo camera trap data, which are matched
#'  with the real data using the random forest algorithm, in order to find the best fit of animal abundance
#'  among the abundance from 1 to 10 taken by each camera for one species. Such simulation can be repeated for
#'  several times defined by number of iteration.
#'
#' @author Xinhai Li (Xinhai_li_edu@126.com)
#'
#' @param x A data.frame with column names "Lon", "Lat", "Group_size", "Date", "Time"
#' @param detect The detection radias (m) of a camera.
#' @param bearing The bearing direction of a camera.
#' @param step.N The number of steps the animal walks during the camera trapping.
#' @param step.L The mean step length (m) of the animal.
#' @param step.V The standard diviation of the step length
#' @param bias The standard diviation of the changing angle (degree) between two steps
#' @param range Maximum distance (m) the animal moves from the original site.
#' @param ind The number of individuals that are simulated.
#' @param iteration The number of simulations.
#'
#' @return A dataframe with the first column to be the number of individuals, and the rest columns
#'  are number of pictures (simulated) for each camera
#'
#' @examples
#'
#'## Key parameters
#'## Survey ============================================================
#'detect <- 200 # camera detection distance: 200m
#'bearing = runif(camera.N, 0, 2*pi) #camera directions
#'ind <- 5
#'iteration <- 2
#'
#'## Movement ==========================================================
#'# step.N <- 3000 # number of steps
#'# step.L <- 10 # mean step length: 10m
#'# step.V <- 2 # SD of step length
#'# bias   <- 15/360*2*pi # SD of normal distribution for moving bearing
#'# range  <- 4000
#'
#'## simulation
#'# (sim.out = simuCamtrap(trapresult, ind = 10, iteration = 3))
#'
#' @export
#'

simuCamtrap = function(x, detect = 50, bearing = runif(camera.N, 0, 2*pi), # detect = 0.200 / (40000/360) for latlon
                        step.N = 5000, step.L = 10,
                        step.V = 2, bias = 30/360*2*pi, range = 4000,
                        ind = 10, iteration = 3){

  camera = unique(x[,c('Lon','Lat')]) # x=trap.out
  camera = cbind(camera, Count=0)
  camera.N <- nrow(camera)
  out = as.data.frame(matrix(data = 0, nrow = ind*iteration, ncol = camera.N))


  for (ite in 1:iteration){#  iterations
    plotCamtrap(x)
    for (k in 1:ind){
      footchain = data.frame(ID=1:step.N, X=NA, Y=NA) # for plotting footchain
      loc.x = runif(1, min(x$Lon) + 0.25*(max(x$Lon) - min(x$Lon)), max(x$Lon)-0.25*(max(x$Lon) - min(x$Lon))) # random initial location
      loc.y = runif(1, min(x$Lat) + 0.25*(max(x$Lat) - min(x$Lat)), max(x$Lat)-0.25*(max(x$Lat) - min(x$Lat)))
      loc.x.0 = loc.x; loc.y.0 = loc.y

      ### MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM  simulating movement  MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
      theta  <- runif(1, 0, 2*pi) # moving bearing of the first step
      for (i in 1:step.N){   #walking steps
        for (j in 1:camera.N){ # number of cameras
          d = ((loc.x - camera$Lon[j])^2 + (loc.y - camera$Lat[j])^2)^.5
          bear = atan((loc.y - camera$Lat[j])/(loc.x - camera$Lon[j]))
          if(d < detect & abs(bear-bearing[j]) < 50/360*2*pi)   camera$Count[j] <- camera$Count[j] + 1 # 50 degree detetion region
        }
        move = step.L * rnorm(1, 1, step.V) #
        loc.x = loc.x + move*cos(theta) #
        loc.y = loc.y + move*sin(theta)
        theta.f = theta + rnorm(1,0,bias) # move forward
        if (loc.x > loc.x.0)    theta.b <- pi + atan((loc.y - loc.y.0)/(loc.x - loc.x.0))+ rnorm(1,0,bias*2)#return to origin
        if (loc.x < loc.x.0)    theta.b <-      atan((loc.y - loc.y.0)/(loc.x - loc.x.0))+ rnorm(1,0,bias*2)#return to origin
        dist = ((loc.x - loc.x.0)^2 + (loc.y - loc.y.0)^2)^.5
        theta = sample(c(theta.f, theta.b), 1, prob=c((1-dist/range), dist/range)) #home range
        footchain$X[i] = loc.x;   footchain$Y[i] = loc.y # for plotting footchain
      }
      # plot footchain
      lines(footchain$X, footchain$Y, col=rainbow(100)[sample(1:100, 1)])
      points(loc.x.0,loc.y.0, col='blue',pch=17,cex=.8)
      points(footchain$X[step.N], footchain$Y[step.N], col='red',pch=15,cex=.8)
      # points(camera$Lon, camera$Lat, col='black',pch=16)
      ### MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM  simulating movement  MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM

      camera$Count = sort(camera$Count) # NOT spatial explicit
      out[k+(ite-1)*ind,] = camera$Count            # generate out
      print(paste('Iteration ', ite, ';  Ind. ', k, sep=''))
    }
    camera$Count = camera$Count * 0
  }

  Ind = rep(1:ind, iteration)
  out = cbind(Ind = Ind, out)
  assign('sim.out', out, envir = .GlobalEnv)
  # write.csv(out, 'D:/sim.out.csv', row.names = F)
  return(out)
}

library(compiler)
simuCamtrap <- cmpfun(simuCamtrap) # system.time(simuCamtrap(trap.out, ind = 3, iteration = 1))
#SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS







#PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP
#' Predict population abundance within the range of camera trap grid
#'
#' @description This function matches the real camera trap result with pseudo camera trap result simulated for a series number of individuals,
#'  to find the best fit of animal abundance with real camera trap result.
#'
#' @author Xinhai Li (Xinhai_li_edu@126.com)
#'
#' @param simu The result of function simuCamtrap().
#' @param x A data.frame with column names "Lon", "Lat", "Group_size", "Date", "Time"
#' @param plot a boolean variable, if TRUE, plot the probability density of estimated animal abundance
#'
#' @return The mean value, 95% confidence intervals of the predicted animal abundance, based on
#'  a vector of the predicted animal abundance from 1000 random forest trees.
#'
#' @examples
#'
#'  attach(trapresult)
#'  # sim.out = simuCamtrap(trapresult, ind = 10, iteration = 3) # need a few minutes
#'  predictCamtrap(sim.out, trapresult, plot=T)
#'
#' @import randomForest
#' @export
#'

predictCamtrap = function(simu, x, plot=F){
  library(randomForest)
  if (!requireNamespace("randomForest", quietly = TRUE)) {
    stop("randomForest needed for this function to work. Please install it.", call. = FALSE)
  }

  RF = randomForest(simu[,c(2:ncol(simu))], simu[,1], prox=TRUE, importance=TRUE, ntree=1000)

  sum = aggregate(x$Group_size, by = list(x$Lat, x$Lon), sum)
  colnames(sum) = c('Lat','Lon','Count')
  obs = sort(sum$Count)
  pred <- predict(RF, obs, type="response", predict.all=TRUE)
  pred.rf.int <- apply( pred$individual, 1, function(x) { quantile(x, c(0.025, 0.5, 0.975) )})
  if(plot){
    plot(density(pred$individual),xlab='Number of individuals', ylab='Frequency',col='darkgrey',xlim=c(0,max(simu$Ind)),lwd=2,
         main=paste('Predicted population size:',round(pred.rf.int[2,1],1), sep=' '))
    abline(v = pred$aggregate, lwd=2) # mean value of 1000 trees
    abline(v = c(pred.rf.int[1,1], pred.rf.int[3,1]), lwd=1, col='black',lty=2)
  }
  return(round(pred.rf.int, 1))
}
predictCamtrap <- cmpfun(predictCamtrap)
#PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP

# predictCamtrap(sim.out, trapresult, plot=T)






# Footprint chain analysis
## FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
#' Plot the trajectory of footprint chain
#'
#' @description Plot the trajectory of footprint chain, highlighting the starting and ending points.
#'
#' @author Xinhai Li (Xinhai_li_edu@126.com)
#'
#' @param chain A data.frame with column names "Lon", "Lat", and "Date", in the order of recording time
#'  at the interval of one second
#'
#' @return
#'
#' @examples
#'
#'  attach(footprintchain)
#'  plotFootprint(footprintchain)
#'
#' @export
#'


plotFootprint = function(chain){
  plot(chain$Lon, chain$Lat, type='l', xlab='Longitude', ylab='Latitude')
  points(chain$Lon[1], chain$Lat[1], col = 'blue', cex=2, pch=17)
  points(chain$Lon[nrow(chain)], chain$Lat[nrow(chain)], col = 'red', cex=2, pch=15)
}
## FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF








## BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
#' Show how likely the animal would turn during moving
#'
#' @description Plot the probability density of step length, and probability density of turning angle between two steps.
#'  The step length can be defined by "scale" as the distance between every one second, two seconds, etc.
#'
#' @author Xinhai Li (Xinhai_li_edu@126.com)
#'
#' @param chain A data.frame with column names "Lon", "Lat", and "Date", in the order of recording time
#'  at the interval of one second
#'
#' @param scale A value defining the step length
#'
#' @return
#'
#' @examples
#'
#'  attach(footprintchain)
#'  moveBias(footprintchain, scale=2)
#'
#' @export
#'

moveBias = function(chain, scale){
  chain = cbind(chain, dist=NA, theta=NA, delta.th=NA)
  chain = chain[seq(1, nrow(chain), by=scale),]
  N = nrow(chain)

  for (i in 1:(N-1)){
    chain$dist[i+1] = (((chain$Lat[i+1]-chain$Lat[i])*39946.79/360)^2+
                         ((chain$Lon[i+1]-chain$Lon[i])*pi*12756.32/360*cos(chain$Lat[i]*pi*2/360))^2)^0.5
    chain$theta[i+1] = asin((chain$Lat[i+1]-chain$Lat[i])*39946.79/360 / chain$dist[i+1]) *360/2/pi # bearing
  }

  chain = chain[!is.na(chain$theta),] #remove records with 0 distance
  chain$dist = chain$dist*1000
  chain = chain[!chain$dist>400,] # remove records across survey regions

  # Angle of deflection
  N = nrow(chain);N
  for (j in 1:(N-1)){
    chain$delta.th[j+1] = chain$theta[j+1] - chain$theta[j]
  }
  chain = chain[-1,]
  par(mfrow=c(1,2))
  plot(density(chain$dist),xlab="Distance (m)", main=paste('Distance of a step: ', round(mean(chain$dist),2), "m"), cex=1.5)
  plot(density(chain$delta.th),xlab="Angle of deflection (degree)", main=paste('SD of deflection = ',
                                                                               round(sd(chain$delta.th),2)), cex=1.5)
}
## BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB

#




## RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
#' Calculate animal density using Rowcliffe's equation (Rowcliffe 2008)
#'
#' @description Calculate animal density using Rowcliffe's random encounter models.
#'
#' @author Xinhai Li (Xinhai_li_edu@126.com)
#'
#' @param x A data.frame with column names "Lon", "Lat", "Group_size", "Date", "Time".
#' @param r Detection range (km) of the camera.
#' @param theta Detection angle of the camera
#' @param v Mean velocity (km/h) of the animal.
#' @param duration Days for camera trapping.
#'
#' @return
#'
#' @examples
#'
#'  attach(trapresult)
#'  Rowcliffe(trapresult, r=0.02, theta = 40, v = 2, duration = 40) # unit: km
#'
#' @export
#'

## population density (Rowcliffe 2008)
Rowcliffe = function(x, r, theta, v, duration){
  sum = aggregate(x$Group_size, by = list(x$Lat, x$Lon), sum)
  colnames(sum) = c('Lat','Lon','Count')
  D = sum$Count * pi / (duration*v*r*(2+theta*2*pi/360)) # population density (Rowcliffe 2008)
  density = c(round(mean(D),2), round(sd(D),2))
  names(density) = c('Density', 'SD')
  return(density)
}
## RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
#
