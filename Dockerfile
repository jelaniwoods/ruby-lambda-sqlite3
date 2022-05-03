FROM public.ecr.aws/lambda/ruby:2.7
# Install and build sqlite3
RUN yum update -y && yum install tar wget -y
RUN yum groupinstall "Development Tools" -y
WORKDIR /sqlite3
RUN wget https://kojipkgs.fedoraproject.org//packages/sqlite/3.8.11/1.fc21/x86_64/sqlite-devel-3.8.11-1.fc21.x86_64.rpm
RUN wget https://kojipkgs.fedoraproject.org//packages/sqlite/3.8.11/1.fc21/x86_64/sqlite-3.8.11-1.fc21.x86_64.rpm
RUN yum install sqlite-3.8.11-1.fc21.x86_64.rpm sqlite-devel-3.8.11-1.fc21.x86_64.rpm -y
WORKDIR ${LAMBDA_TASK_ROOT}
# Copy function code
COPY app.rb ${LAMBDA_TASK_ROOT}
COPY models/* models/
COPY test/* test/

# Copy dependency management file
COPY Gemfile ${LAMBDA_TASK_ROOT}
# TODO can I immediately save it to /tmp/?
# COPY msm.sqlite3 /tmp/
COPY msm.sqlite3 ${LAMBDA_TASK_ROOT}
# Install dependencies under LAMBDA_TASK_ROOT
ENV GEM_HOME=${LAMBDA_TASK_ROOT}

RUN bundle install

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
# filename.method_name
CMD [ "app.lambda_handler" ]
