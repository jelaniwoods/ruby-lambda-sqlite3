FROM public.ecr.aws/lambda/ruby:2.7
# Install and build sqlite3
RUN yum update -y && yum install tar wget -y
RUN yum groupinstall "Development Tools" -y
WORKDIR sqlite3
RUN wget https://www.sqlite.org/2022/sqlite-autoconf-3380300.tar.gz
RUN tar xvfz sqlite-autoconf-3380300.tar.gz
RUN cd sqlite-autoconf-3380300 && ./configure && make && make install

WORKDIR ${LAMBDA_TASK_ROOT}
# Copy function code
COPY app.rb ${LAMBDA_TASK_ROOT}

# Copy dependency management file
COPY Gemfile ${LAMBDA_TASK_ROOT}
# Install dependencies under LAMBDA_TASK_ROOT
ENV GEM_HOME=${LAMBDA_TASK_ROOT}

RUN bundle install

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
# filename.method_name
CMD [ "app.lambda_handler" ]
